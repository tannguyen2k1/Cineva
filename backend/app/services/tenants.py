from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import hash_password
from app.models import Role, Tenant, User
from app.repositories import role as role_repo
from app.repositories import tenant as tenant_repo
from app.repositories import user as user_repo
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
    tenants, total = await tenant_repo.list_tenants_page(
        db, page=page, page_size=page_size, search=search, status=status
    )
    data = [
        {
            "id": t.id,
            "name": t.name,
            "domain": t.domain,
            "userCount": tenant_repo.active_user_count(t),
            "isActive": t.is_active,
            "createdAt": t.created_at,
        }
        for t in tenants
    ]
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

    if await tenant_repo.find_by_name(db, name):
        raise HTTPException(status_code=409, detail="Tên tenant đã tồn tại")

    if body.domain and await tenant_repo.find_by_domain(db, body.domain):
        raise HTTPException(status_code=409, detail="Domain đã tồn tại")

    settings = get_settings()
    tenant = await tenant_repo.add_tenant(
        db, Tenant(name=name, domain=body.domain or None, is_active=body.isActive)
    )

    role = await role_repo.add_role(
        db,
        Role(tenant_id=tenant.id, name="Admin", description="Quản trị viên hệ thống"),
    )

    await ensure_system_permissions(db, tenant.id)

    admin_user = await user_repo.add_user(
        db,
        User(
            tenant_id=tenant.id,
            username=settings.default_admin_username,
            password=hash_password(settings.default_admin_password),
            full_name="Super Admin",
            is_active=True,
        ),
    )
    await user_repo.add_user_roles(
        db, user_id=admin_user.id, tenant_id=tenant.id, role_ids=[role.id]
    )
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
    tenant = await tenant_repo.get_by_id(db, tenant_id, with_users=True)
    if not tenant:
        raise HTTPException(status_code=404, detail="Không tìm thấy tenant")

    if body.name is not None:
        name = body.name.strip()
        if await tenant_repo.find_by_name(db, name, exclude_id=tenant_id):
            raise HTTPException(status_code=409, detail="Tên tenant đã tồn tại")
        tenant.name = name

    if body.domain is not None:
        if body.domain and await tenant_repo.find_by_domain(
            db, body.domain, exclude_id=tenant_id
        ):
            raise HTTPException(status_code=409, detail="Domain đã tồn tại")
        tenant.domain = body.domain or None

    if body.isActive is not None:
        if body.isActive is False and tenant_id == actor_tenant_id:
            raise HTTPException(status_code=400, detail="Không thể khóa tenant hiện tại")
        tenant.is_active = body.isActive

    await db.commit()
    await db.refresh(tenant)
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
            "userCount": tenant_repo.active_user_count(tenant),
        },
    }


async def delete_tenant(
    db: AsyncSession, actor_tenant_id: str, actor_id: str | None, tenant_id: str
) -> dict:
    if tenant_id == actor_tenant_id:
        raise HTTPException(status_code=400, detail="Không thể xóa tenant hiện tại")

    tenant = await tenant_repo.get_by_id(db, tenant_id)
    if not tenant:
        raise HTTPException(status_code=404, detail="Không tìm thấy tenant")

    await tenant_repo.soft_delete(db, tenant)
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
