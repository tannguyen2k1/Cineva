from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Permission, Role, RolePermission


async def list_all(db: AsyncSession) -> list[Permission]:
    return list(
        (
            await db.execute(select(Permission))
        )
        .scalars()
        .all()
    )


async def get_ids(
    db: AsyncSession, *, permission_ids: list[str]
) -> list[Permission]:
    if not permission_ids:
        return []
    return list(
        (
            await db.execute(
                select(Permission).where(
                    Permission.id.in_(permission_ids),
                )
            )
        )
        .scalars()
        .all()
    )


async def find_by_action_resource(
    db: AsyncSession, *, action: str, resource: str
) -> Permission | None:
    return (
        await db.execute(
            select(Permission).where(
                Permission.action == action,
                Permission.resource == resource,
            )
        )
    ).scalar_one_or_none()


async def add_permission(db: AsyncSession, permission: Permission) -> Permission:
    db.add(permission)
    await db.flush()
    return permission


async def find_admin_role(db: AsyncSession) -> Role | None:
    return (
        await db.execute(
            select(Role).where(
                Role.name == "Admin",
                Role.deleted_at.is_(None),
            )
        )
    ).scalar_one_or_none()


async def find_role_permission(
    db: AsyncSession, *, role_id: str, permission_id: str
) -> RolePermission | None:
    return (
        await db.execute(
            select(RolePermission).where(
                RolePermission.role_id == role_id,
                RolePermission.permission_id == permission_id,
            )
        )
    ).scalar_one_or_none()


async def add_role_permission(
    db: AsyncSession, *, role_id: str, permission_id: str
) -> None:
    db.add(
        RolePermission(
            role_id=role_id, permission_id=permission_id
        )
    )
