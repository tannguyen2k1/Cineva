from __future__ import annotations

from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Permission, Role, RolePermission, User, UserRole
from app.schemas import RoleCreate, RolePermissionsUpdate, RoleUpdate
from app.services.system_log import write_system_log


async def list_roles(
    db: AsyncSession,
    tenant_id: str,
    *,
    page: int = 1,
    page_size: int = 10,
    search: str | None = None,
) -> dict:
    filters = [Role.tenant_id == tenant_id, Role.deleted_at.is_(None)]
    if search:
        like = f"%{search}%"
        filters.append(or_(Role.name.ilike(like), Role.description.ilike(like)))

    total = (
        await db.execute(select(func.count()).select_from(Role).where(*filters))
    ).scalar_one()
    result = await db.execute(
        select(Role)
        .where(*filters)
        .options(selectinload(Role.user_roles).selectinload(UserRole.user))
        .order_by(Role.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    roles = result.scalars().all()
    data = []
    for role in roles:
        user_count = sum(
            1 for ur in role.user_roles if ur.user and ur.user.deleted_at is None
        )
        data.append(
            {
                "id": role.id,
                "name": role.name,
                "description": role.description,
                "userCount": user_count,
                "createdAt": role.created_at,
            }
        )
    return {
        "success": True,
        "data": data,
        "total": total,
        "page": page,
        "pageSize": page_size,
    }


async def create_role(
    db: AsyncSession, tenant_id: str, actor_id: str | None, body: RoleCreate
) -> dict:
    name = (body.name or "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="Tên vai trò là bắt buộc")

    existing = await db.execute(
        select(Role).where(
            Role.tenant_id == tenant_id, Role.name == name, Role.deleted_at.is_(None)
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Tên vai trò đã tồn tại")

    role = Role(tenant_id=tenant_id, name=name, description=body.description)
    db.add(role)
    await db.commit()
    await db.refresh(role)
    await write_system_log(
        db,
        tenant_id=tenant_id,
        user_id=actor_id,
        action="CREATE_ROLE",
        resource="Role",
        details={"id": role.id, "name": role.name},
    )
    return {
        "success": True,
        "data": {
            "id": role.id,
            "name": role.name,
            "description": role.description,
            "createdAt": role.created_at,
            "userCount": 0,
        },
    }


async def update_role(
    db: AsyncSession, tenant_id: str, actor_id: str | None, role_id: str, body: RoleUpdate
) -> dict:
    result = await db.execute(
        select(Role)
        .where(Role.id == role_id, Role.tenant_id == tenant_id, Role.deleted_at.is_(None))
        .options(selectinload(Role.user_roles).selectinload(UserRole.user))
    )
    role = result.scalar_one_or_none()
    if not role:
        raise HTTPException(status_code=404, detail="Không tìm thấy vai trò")

    if body.name is not None:
        name = body.name.strip()
        if not name:
            raise HTTPException(status_code=400, detail="Tên vai trò không được trống")
        dup = await db.execute(
            select(Role).where(
                Role.tenant_id == tenant_id,
                Role.name == name,
                Role.deleted_at.is_(None),
                Role.id != role_id,
            )
        )
        if dup.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Tên vai trò đã tồn tại")
        role.name = name
    if body.description is not None:
        role.description = body.description

    await db.commit()
    await db.refresh(role)
    user_count = sum(1 for ur in role.user_roles if ur.user and ur.user.deleted_at is None)
    await write_system_log(
        db,
        tenant_id=tenant_id,
        user_id=actor_id,
        action="UPDATE_ROLE",
        resource="Role",
        details={"id": role.id, "name": role.name},
    )
    return {
        "success": True,
        "data": {
            "id": role.id,
            "name": role.name,
            "description": role.description,
            "createdAt": role.created_at,
            "userCount": user_count,
        },
    }


async def delete_role(
    db: AsyncSession, tenant_id: str, actor_id: str | None, role_id: str
) -> dict:
    result = await db.execute(
        select(Role)
        .where(Role.id == role_id, Role.tenant_id == tenant_id, Role.deleted_at.is_(None))
        .options(selectinload(Role.user_roles).selectinload(UserRole.user))
    )
    role = result.scalar_one_or_none()
    if not role:
        raise HTTPException(status_code=404, detail="Không tìm thấy vai trò")

    active_users = sum(1 for ur in role.user_roles if ur.user and ur.user.deleted_at is None)
    if active_users > 0:
        raise HTTPException(
            status_code=400,
            detail="Không thể xóa vai trò đang được gán cho người dùng",
        )

    role.deleted_at = datetime.now(timezone.utc)
    await db.commit()
    await write_system_log(
        db,
        tenant_id=tenant_id,
        user_id=actor_id,
        action="DELETE_ROLE",
        resource="Role",
        details={"id": role.id, "name": role.name},
    )
    return {"success": True, "message": "Đã xóa vai trò"}


async def get_role_permissions(db: AsyncSession, tenant_id: str, role_id: str) -> dict:
    result = await db.execute(
        select(Role).where(
            Role.id == role_id, Role.tenant_id == tenant_id, Role.deleted_at.is_(None)
        )
    )
    role = result.scalar_one_or_none()
    if not role:
        raise HTTPException(status_code=404, detail="Không tìm thấy vai trò")

    perms = (
        await db.execute(select(RolePermission).where(RolePermission.role_id == role_id))
    ).scalars().all()
    return {
        "success": True,
        "data": {
            "roleId": role.id,
            "roleName": role.name,
            "permissionIds": [p.permission_id for p in perms],
        },
    }


async def update_role_permissions(
    db: AsyncSession,
    tenant_id: str,
    actor_id: str | None,
    role_id: str,
    body: RolePermissionsUpdate,
) -> dict:
    result = await db.execute(
        select(Role).where(
            Role.id == role_id, Role.tenant_id == tenant_id, Role.deleted_at.is_(None)
        )
    )
    role = result.scalar_one_or_none()
    if not role:
        raise HTTPException(status_code=404, detail="Không tìm thấy vai trò")

    permission_ids = body.permissionIds or []
    if permission_ids:
        found = (
            await db.execute(
                select(Permission).where(
                    Permission.tenant_id == tenant_id,
                    Permission.id.in_(permission_ids),
                )
            )
        ).scalars().all()
        if len(found) != len(permission_ids):
            raise HTTPException(status_code=400, detail="Một hoặc nhiều quyền không hợp lệ")

    existing = (
        await db.execute(select(RolePermission).where(RolePermission.role_id == role_id))
    ).scalars().all()
    for rp in existing:
        await db.delete(rp)
    await db.flush()

    for pid in permission_ids:
        db.add(RolePermission(role_id=role_id, permission_id=pid, tenant_id=tenant_id))

    await db.commit()
    await write_system_log(
        db,
        tenant_id=tenant_id,
        user_id=actor_id,
        action="UPDATE_ROLE_PERMISSIONS",
        resource="Role",
        details={"id": role.id, "name": role.name, "permissionCount": len(permission_ids)},
    )
    return {
        "success": True,
        "data": {"roleId": role_id, "permissionIds": permission_ids},
    }
