from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.permissions import SYSTEM_PERMISSIONS
from app.models import Permission, User
from app.repositories import permission as permission_repo
from app.repositories.user import user_with_permissions_options


def user_perm_options():
    return user_with_permissions_options()


async def ensure_system_permissions(db: AsyncSession) -> list[str]:
    ensured_ids: list[str] = []

    for p in SYSTEM_PERMISSIONS:
        existing = await permission_repo.find_by_action_resource(
            db, action=p["action"], resource=p["resource"]
        )
        if not existing:
            existing = await permission_repo.add_permission(
                db,
                Permission(
                    action=p["action"],
                    resource=p["resource"],
                    description=p["description"],
                ),
            )
        ensured_ids.append(existing.id)

    admin_role = await permission_repo.find_admin_role(db)
    if admin_role:
        for permission_id in ensured_ids:
            link = await permission_repo.find_role_permission(
                db, role_id=admin_role.id, permission_id=permission_id
            )
            if not link:
                await permission_repo.add_role_permission(
                    db,
                    role_id=admin_role.id,
                    permission_id=permission_id,
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
