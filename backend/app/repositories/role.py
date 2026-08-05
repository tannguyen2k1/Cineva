from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Role, RolePermission, UserRole


def role_with_users_options():
    return selectinload(Role.user_roles).selectinload(UserRole.user)


async def count_roles(db: AsyncSession, *filters) -> int:
    return (
        await db.execute(select(func.count()).select_from(Role).where(*filters))
    ).scalar_one()


async def list_roles_page(
    db: AsyncSession,
    *,
    tenant_id: str,
    page: int,
    page_size: int,
    search: str | None = None,
) -> tuple[list[Role], int]:
    filters = [Role.tenant_id == tenant_id, Role.deleted_at.is_(None)]
    if search:
        like = f"%{search}%"
        filters.append(or_(Role.name.ilike(like), Role.description.ilike(like)))

    total = await count_roles(db, *filters)
    result = await db.execute(
        select(Role)
        .where(*filters)
        .options(role_with_users_options())
        .order_by(Role.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return list(result.scalars().all()), total


async def get_by_id(
    db: AsyncSession,
    *,
    role_id: str,
    tenant_id: str,
    with_users: bool = False,
) -> Role | None:
    stmt = select(Role).where(
        Role.id == role_id,
        Role.tenant_id == tenant_id,
        Role.deleted_at.is_(None),
    )
    if with_users:
        stmt = stmt.options(role_with_users_options())
    return (await db.execute(stmt)).scalar_one_or_none()


async def find_by_name(
    db: AsyncSession, *, tenant_id: str, name: str, exclude_id: str | None = None
) -> Role | None:
    filters = [
        Role.tenant_id == tenant_id,
        Role.name == name,
        Role.deleted_at.is_(None),
    ]
    if exclude_id:
        filters.append(Role.id != exclude_id)
    return (await db.execute(select(Role).where(*filters))).scalar_one_or_none()


async def get_ids_in_tenant(
    db: AsyncSession, *, tenant_id: str, role_ids: list[str]
) -> list[Role]:
    if not role_ids:
        return []
    return list(
        (
            await db.execute(
                select(Role).where(
                    Role.tenant_id == tenant_id,
                    Role.id.in_(role_ids),
                    Role.deleted_at.is_(None),
                )
            )
        )
        .scalars()
        .all()
    )


async def count_active_in_tenant(db: AsyncSession, tenant_id: str) -> int:
    return await count_roles(
        db, Role.tenant_id == tenant_id, Role.deleted_at.is_(None)
    )


async def add_role(db: AsyncSession, role: Role) -> Role:
    db.add(role)
    await db.flush()
    return role


async def soft_delete(db: AsyncSession, role: Role) -> None:
    role.deleted_at = datetime.now(timezone.utc)


async def list_role_permissions(db: AsyncSession, role_id: str) -> list[RolePermission]:
    return list(
        (
            await db.execute(
                select(RolePermission).where(RolePermission.role_id == role_id)
            )
        )
        .scalars()
        .all()
    )


async def replace_role_permissions(
    db: AsyncSession,
    *,
    role_id: str,
    tenant_id: str,
    permission_ids: list[str],
) -> None:
    existing = await list_role_permissions(db, role_id)
    for rp in existing:
        await db.delete(rp)
    await db.flush()
    for pid in permission_ids:
        db.add(
            RolePermission(role_id=role_id, permission_id=pid, tenant_id=tenant_id)
        )


def active_user_count(role: Role) -> int:
    return sum(1 for ur in role.user_roles if ur.user and ur.user.deleted_at is None)
