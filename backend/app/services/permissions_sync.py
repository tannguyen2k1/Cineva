from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.permissions import SYSTEM_PERMISSIONS
from app.models import Permission, Role, RolePermission, User


def user_perm_options():
    return (
        selectinload(User.user_roles)
        .selectinload(__import__("app.models", fromlist=["UserRole"]).UserRole.role)
        .selectinload(Role.role_permissions)
        .selectinload(RolePermission.permission)
    )


async def ensure_system_permissions(db: AsyncSession, tenant_id: str) -> list[str]:
    ensured_ids: list[str] = []

    for p in SYSTEM_PERMISSIONS:
        result = await db.execute(
            select(Permission).where(
                Permission.tenant_id == tenant_id,
                Permission.action == p["action"],
                Permission.resource == p["resource"],
            )
        )
        existing = result.scalar_one_or_none()
        if not existing:
            existing = Permission(
                tenant_id=tenant_id,
                action=p["action"],
                resource=p["resource"],
                description=p["description"],
            )
            db.add(existing)
            await db.flush()
        ensured_ids.append(existing.id)

    admin_result = await db.execute(
        select(Role).where(
            Role.tenant_id == tenant_id,
            Role.name == "Admin",
            Role.deleted_at.is_(None),
        )
    )
    admin_role = admin_result.scalar_one_or_none()
    if admin_role:
        for permission_id in ensured_ids:
            link_result = await db.execute(
                select(RolePermission).where(
                    RolePermission.role_id == admin_role.id,
                    RolePermission.permission_id == permission_id,
                )
            )
            if not link_result.scalar_one_or_none():
                db.add(
                    RolePermission(
                        role_id=admin_role.id,
                        permission_id=permission_id,
                        tenant_id=tenant_id,
                    )
                )

    await db.commit()
    return ensured_ids


def collect_permissions_from_user(user: User) -> list[str]:
    perms: set[str] = set()
    for ur in user.user_roles or []:
        role = ur.role
        if not role:
            continue
        for rp in role.role_permissions or []:
            if rp.permission:
                perms.add(f"{rp.permission.action}:{rp.permission.resource}")
    return sorted(perms)
