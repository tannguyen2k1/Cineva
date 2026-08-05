from __future__ import annotations

import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import HTTPException, UploadFile
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.core.security import hash_password
from app.models import Role, User, UserRole
from app.schemas import ProfileUpdate, UserCreate, UserUpdate
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
    filters = [User.tenant_id == tenant_id, User.deleted_at.is_(None)]
    if search:
        like = f"%{search}%"
        filters.append(or_(User.username.ilike(like), User.full_name.ilike(like)))
    if status == "active":
        filters.append(User.is_active.is_(True))
    elif status == "inactive":
        filters.append(User.is_active.is_(False))

    total = (
        await db.execute(select(func.count()).select_from(User).where(*filters))
    ).scalar_one()
    result = await db.execute(
        select(User)
        .where(*filters)
        .options(selectinload(User.user_roles).selectinload(UserRole.role))
        .order_by(User.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    users = result.scalars().all()
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

    existing = await db.execute(
        select(User).where(
            User.tenant_id == tenant_id,
            User.username == body.username,
            User.deleted_at.is_(None),
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Username đã tồn tại")

    if body.roleIds:
        roles = (
            await db.execute(
                select(Role).where(
                    Role.tenant_id == tenant_id,
                    Role.id.in_(body.roleIds),
                    Role.deleted_at.is_(None),
                )
            )
        ).scalars().all()
        if len(roles) != len(body.roleIds):
            raise HTTPException(status_code=400, detail="Một hoặc nhiều vai trò không hợp lệ")

    user = User(
        tenant_id=tenant_id,
        username=body.username.strip(),
        password=hash_password(body.password),
        full_name=body.fullName,
        email=body.email,
        is_active=body.isActive,
    )
    db.add(user)
    await db.flush()

    for rid in body.roleIds:
        db.add(UserRole(user_id=user.id, role_id=rid, tenant_id=tenant_id))

    await db.commit()
    await db.refresh(user)
    result = await db.execute(
        select(User)
        .where(User.id == user.id)
        .options(selectinload(User.user_roles).selectinload(UserRole.role))
    )
    user = result.scalar_one()

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
    result = await db.execute(
        select(User)
        .where(User.id == user_id, User.tenant_id == tenant_id, User.deleted_at.is_(None))
        .options(selectinload(User.user_roles).selectinload(UserRole.role))
    )
    user = result.scalar_one_or_none()
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

    if body.roleIds is not None:
        roles = (
            await db.execute(
                select(Role).where(
                    Role.tenant_id == tenant_id,
                    Role.id.in_(body.roleIds),
                    Role.deleted_at.is_(None),
                )
            )
        ).scalars().all()
        if body.roleIds and len(roles) != len(body.roleIds):
            raise HTTPException(status_code=400, detail="Một hoặc nhiều vai trò không hợp lệ")
        for ur in list(user.user_roles):
            await db.delete(ur)
        await db.flush()
        for rid in body.roleIds:
            db.add(UserRole(user_id=user.id, role_id=rid, tenant_id=tenant_id))

    await db.commit()
    result = await db.execute(
        select(User)
        .where(User.id == user.id)
        .options(selectinload(User.user_roles).selectinload(UserRole.role))
    )
    user = result.scalar_one()
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

    result = await db.execute(
        select(User).where(
            User.id == user_id, User.tenant_id == tenant_id, User.deleted_at.is_(None)
        )
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

    user.deleted_at = datetime.now(timezone.utc)
    user.is_active = False
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
    result = await db.execute(
        select(User).where(
            User.id == user_id, User.tenant_id == tenant_id, User.deleted_at.is_(None)
        )
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

    if body.fullName is not None:
        user.full_name = body.fullName
    if body.email is not None:
        user.email = body.email
    if body.password:
        user.password = hash_password(body.password)

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
    result = await db.execute(
        select(User).where(
            User.id == user_id, User.tenant_id == tenant_id, User.deleted_at.is_(None)
        )
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    user.avatar = avatar_url
    await db.commit()
    return {"success": True, "data": {"avatar": avatar_url}}
