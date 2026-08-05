from __future__ import annotations

import uuid
from pathlib import Path

from fastapi import HTTPException, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import hash_password
from app.models import User
from app.repositories import role as role_repo
from app.repositories import user as user_repo
from app.schemas import ProfileUpdate, UserCreate, UserUpdate
from app.services.refresh_sessions import revoke_user_sessions
from app.services.server_stats import ensure_upload_dirs
from app.services.system_log import write_system_log

ALLOWED_MIME = {"image/jpeg", "image/png", "image/gif", "image/webp"}
ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
MAX_AVATAR_BYTES = 5 * 1024 * 1024


def _serialize_user(user: User) -> dict:
    roles = [ur.role.name for ur in user.user_roles if ur.role and ur.role.deleted_at is None]
    role_ids = [ur.role_id for ur in user.user_roles if ur.role and ur.role.deleted_at is None]
    return {
        "id": user.id,
        "username": user.username,
        "email": user.email,
        "fullName": user.full_name,
        "avatar": user.avatar,
        "isActive": user.is_active,
        "createdAt": user.created_at,
        "roles": roles or ["User"],
        "roleIds": role_ids,
    }


async def list_users(
    db: AsyncSession,
    tenant_id: str,
    *,
    page: int = 1,
    page_size: int = 10,
    search: str | None = None,
    status: str | None = None,
) -> dict:
    users, total = await user_repo.list_users_page(
        db,
        tenant_id=tenant_id,
        page=page,
        page_size=page_size,
        search=search,
        status=status,
    )
    return {
        "success": True,
        "data": [_serialize_user(u) for u in users],
        "total": total,
        "page": page,
        "pageSize": page_size,
    }


async def create_user(
    db: AsyncSession, tenant_id: str, actor_id: str | None, body: UserCreate
) -> dict:
    if not body.username or not body.password:
        raise HTTPException(status_code=400, detail="Username và password là bắt buộc")
    if len(body.password) < 6:
        raise HTTPException(status_code=400, detail="Mật khẩu tối thiểu 6 ký tự")

    if await user_repo.find_active_username(
        db, tenant_id=tenant_id, username=body.username
    ):
        raise HTTPException(status_code=409, detail="Username đã tồn tại")

    if body.roleIds:
        roles = await role_repo.get_ids_in_tenant(
            db, tenant_id=tenant_id, role_ids=body.roleIds
        )
        if len(roles) != len(body.roleIds):
            raise HTTPException(status_code=400, detail="Một hoặc nhiều vai trò không hợp lệ")

    user = await user_repo.add_user(
        db,
        User(
            tenant_id=tenant_id,
            username=body.username.strip(),
            password=hash_password(body.password),
            full_name=body.fullName,
            email=body.email,
            is_active=body.isActive,
        ),
    )
    await user_repo.add_user_roles(
        db, user_id=user.id, tenant_id=tenant_id, role_ids=body.roleIds
    )
    await db.commit()

    user = await user_repo.get_by_id(
        db, user_id=user.id, tenant_id=tenant_id, with_roles=True
    )
    assert user is not None

    await write_system_log(
        db,
        tenant_id=tenant_id,
        user_id=actor_id,
        action="CREATE_USER",
        resource="User",
        details={"id": user.id, "username": user.username},
    )
    return {"success": True, "data": _serialize_user(user)}


async def update_user(
    db: AsyncSession, tenant_id: str, actor_id: str | None, user_id: str, body: UserUpdate
) -> dict:
    user = await user_repo.get_by_id(
        db, user_id=user_id, tenant_id=tenant_id, with_roles=True
    )
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

    if body.fullName is not None:
        user.full_name = body.fullName
    if body.email is not None:
        user.email = body.email
    if body.isActive is not None:
        user.is_active = body.isActive
    if body.password:
        if len(body.password) < 6:
            raise HTTPException(status_code=400, detail="Mật khẩu tối thiểu 6 ký tự")
        user.password = hash_password(body.password)
        await revoke_user_sessions(db, user.id)

    if body.roleIds is not None:
        roles = await role_repo.get_ids_in_tenant(
            db, tenant_id=tenant_id, role_ids=body.roleIds
        )
        if body.roleIds and len(roles) != len(body.roleIds):
            raise HTTPException(status_code=400, detail="Một hoặc nhiều vai trò không hợp lệ")
        await user_repo.replace_user_roles(
            db, user, tenant_id=tenant_id, role_ids=body.roleIds
        )

    await db.commit()
    user = await user_repo.get_by_id(
        db, user_id=user.id, tenant_id=tenant_id, with_roles=True
    )
    assert user is not None

    await write_system_log(
        db,
        tenant_id=tenant_id,
        user_id=actor_id,
        action="UPDATE_USER",
        resource="User",
        details={"id": user.id, "username": user.username},
    )
    return {"success": True, "data": _serialize_user(user)}


async def delete_user(
    db: AsyncSession, tenant_id: str, actor_id: str, user_id: str
) -> dict:
    if actor_id == user_id:
        raise HTTPException(status_code=400, detail="Không thể tự xóa tài khoản của mình")

    user = await user_repo.get_by_id(db, user_id=user_id, tenant_id=tenant_id)
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

    await user_repo.soft_delete(db, user)
    await db.commit()
    await write_system_log(
        db,
        tenant_id=tenant_id,
        user_id=actor_id,
        action="DELETE_USER",
        resource="User",
        details={"id": user.id, "username": user.username},
    )
    return {"success": True, "message": "Đã xóa người dùng"}


async def update_profile(
    db: AsyncSession, user_id: str, tenant_id: str, body: ProfileUpdate
) -> dict:
    user = await user_repo.get_by_id(db, user_id=user_id, tenant_id=tenant_id)
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

    if body.fullName is not None:
        user.full_name = body.fullName
    if body.email is not None:
        user.email = body.email
    if body.password:
        user.password = hash_password(body.password)
        await revoke_user_sessions(db, user.id)

    await db.commit()
    await db.refresh(user)
    return {
        "success": True,
        "data": {
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "fullName": user.full_name,
            "avatar": user.avatar,
            "isActive": user.is_active,
            "tenant_id": user.tenant_id,
        },
    }


async def upload_avatar(
    db: AsyncSession, user_id: str, tenant_id: str, file: UploadFile
) -> dict:
    if not file.content_type or file.content_type not in ALLOWED_MIME:
        raise HTTPException(status_code=400, detail="Định dạng ảnh không hợp lệ")

    content = await file.read()
    if len(content) > MAX_AVATAR_BYTES:
        raise HTTPException(status_code=400, detail="Ảnh tối đa 5MB")

    suffix = Path(file.filename or "").suffix.lower()
    if suffix not in ALLOWED_EXT:
        raise HTTPException(status_code=400, detail="Phần mở rộng không hợp lệ")

    settings = get_settings()
    root = ensure_upload_dirs(settings.upload_dir)
    filename = f"{uuid.uuid4()}{suffix}"
    dest = root / "avatars" / filename
    dest.write_bytes(content)

    avatar_url = f"/uploads/avatars/{filename}"
    user = await user_repo.get_by_id(db, user_id=user_id, tenant_id=tenant_id)
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    user.avatar = avatar_url
    await db.commit()
    return {"success": True, "data": {"avatar": avatar_url}}
