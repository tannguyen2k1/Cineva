from __future__ import annotations

from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.core.security import hash_password
from app.models import Role, Tenant, User, UserRole
from app.schemas import TenantCreate, TenantUpdate
from app.services.permissions_sync import ensure_system_permissions
from app.services.system_log import write_system_log


async def list_tenants(
    db: AsyncSession,
    *,
    page: int = 1,
    page_size: int = 10,
    search: str | None = None,
    status: str | None = None,
) -> dict:
    filters = [Tenant.deleted_at.is_(None)]
    if search:
        like = f"%{search}%"
        filters.append(or_(Tenant.name.ilike(like), Tenant.domain.ilike(like)))
    if status == "active":
        filters.append(Tenant.is_active.is_(True))
    elif status == "inactive":
        filters.append(Tenant.is_active.is_(False))

    total = (
        await db.execute(select(func.count()).select_from(Tenant).where(*filters))
    ).scalar_one()
    result = await db.execute(
        select(Tenant)
        .where(*filters)
        .options(selectinload(Tenant.users))
        .order_by(Tenant.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    tenants = result.scalars().all()
    data = []
    for t in tenants:
        user_count = sum(1 for u in t.users if u.deleted_at is None)
        data.append(
            {
                "id": t.id,
                "name": t.name,
                "domain": t.domain,
                "userCount": user_count,
                "isActive": t.is_active,
                "createdAt": t.created_at,
            }
        )
    return {
        "success": True,
        "data": data,
        "total": total,
        "page": page,
        "pageSize": page_size,
    }


async def create_tenant(
    db: AsyncSession, actor_tenant_id: str | None, actor_id: str | None, body: TenantCreate
) -> dict:
    name = (body.name or "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="Tên tenant là bắt buộc")

    dup_name = await db.execute(
        select(Tenant).where(Tenant.name == name, Tenant.deleted_at.is_(None))
    )
    if dup_name.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Tên tenant đã tồn tại")

    if body.domain:
        dup_domain = await db.execute(select(Tenant).where(Tenant.domain == body.domain))
        if dup_domain.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Domain đã tồn tại")

    settings = get_settings()
    tenant = Tenant(name=name, domain=body.domain or None, is_active=body.isActive)
    db.add(tenant)
    await db.flush()

    role = Role(tenant_id=tenant.id, name="Admin", description="Quản trị viên hệ thống")
    db.add(role)
    await db.flush()

    await ensure_system_permissions(db, tenant.id)

    admin_user = User(
        tenant_id=tenant.id,
        username=settings.default_admin_username,
        password=hash_password(settings.default_admin_password),
        full_name="Super Admin",
        is_active=True,
    )
    db.add(admin_user)
    await db.flush()
    db.add(UserRole(user_id=admin_user.id, role_id=role.id, tenant_id=tenant.id))
    await db.commit()
    await db.refresh(tenant)

    if actor_tenant_id:
        await write_system_log(
            db,
            tenant_id=actor_tenant_id,
            user_id=actor_id,
            action="CREATE_TENANT",
            resource="Tenant",
            details={"id": tenant.id, "name": tenant.name},
        )

    return {
        "success": True,
        "data": {
            "id": tenant.id,
            "name": tenant.name,
            "domain": tenant.domain,
            "isActive": tenant.is_active,
            "createdAt": tenant.created_at,
            "userCount": 1,
            "defaultAdmin": {
                "username": settings.default_admin_username,
                "password": settings.default_admin_password,
            },
        },
    }


async def update_tenant(
    db: AsyncSession,
    actor_tenant_id: str,
    actor_id: str | None,
    tenant_id: str,
    body: TenantUpdate,
) -> dict:
    result = await db.execute(
        select(Tenant)
        .where(Tenant.id == tenant_id, Tenant.deleted_at.is_(None))
        .options(selectinload(Tenant.users))
    )
    tenant = result.scalar_one_or_none()
    if not tenant:
        raise HTTPException(status_code=404, detail="Không tìm thấy tenant")

    if body.name is not None:
        name = body.name.strip()
        dup = await db.execute(
            select(Tenant).where(
                Tenant.name == name, Tenant.deleted_at.is_(None), Tenant.id != tenant_id
            )
        )
        if dup.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Tên tenant đã tồn tại")
        tenant.name = name

    if body.domain is not None:
        if body.domain:
            dup = await db.execute(
                select(Tenant).where(Tenant.domain == body.domain, Tenant.id != tenant_id)
            )
            if dup.scalar_one_or_none():
                raise HTTPException(status_code=409, detail="Domain đã tồn tại")
        tenant.domain = body.domain or None

    if body.isActive is not None:
        if body.isActive is False and tenant_id == actor_tenant_id:
            raise HTTPException(status_code=400, detail="Không thể khóa tenant hiện tại")
        tenant.is_active = body.isActive

    await db.commit()
    await db.refresh(tenant)
    user_count = sum(1 for u in tenant.users if u.deleted_at is None)
    await write_system_log(
        db,
        tenant_id=actor_tenant_id,
        user_id=actor_id,
        action="UPDATE_TENANT",
        resource="Tenant",
        details={"id": tenant.id, "name": tenant.name},
    )
    return {
        "success": True,
        "data": {
            "id": tenant.id,
            "name": tenant.name,
            "domain": tenant.domain,
            "isActive": tenant.is_active,
            "createdAt": tenant.created_at,
            "userCount": user_count,
        },
    }


async def delete_tenant(
    db: AsyncSession, actor_tenant_id: str, actor_id: str | None, tenant_id: str
) -> dict:
    if tenant_id == actor_tenant_id:
        raise HTTPException(status_code=400, detail="Không thể xóa tenant hiện tại")

    result = await db.execute(
        select(Tenant).where(Tenant.id == tenant_id, Tenant.deleted_at.is_(None))
    )
    tenant = result.scalar_one_or_none()
    if not tenant:
        raise HTTPException(status_code=404, detail="Không tìm thấy tenant")

    tenant.deleted_at = datetime.now(timezone.utc)
    tenant.is_active = False
    if tenant.domain:
        tenant.domain = f"{tenant.domain}__deleted__{tenant.id[:8]}"
    await db.commit()
    await write_system_log(
        db,
        tenant_id=actor_tenant_id,
        user_id=actor_id,
        action="DELETE_TENANT",
        resource="Tenant",
        details={"id": tenant.id, "name": tenant.name},
    )
    return {"success": True, "message": "Đã xóa tenant"}
