from __future__ import annotations

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.timeutil import utcnow
from app.models import Role, RolePermission, User, UserRole


def user_with_roles_options():
    return selectinload(User.user_roles).selectinload(UserRole.role)


def user_with_permissions_options():
    return (
        selectinload(User.user_roles)
        .selectinload(UserRole.role)
        .selectinload(Role.role_permissions)
        .selectinload(RolePermission.permission)
    )


async def count_users(db: AsyncSession, *filters) -> int:
    return (
        await db.execute(select(func.count()).select_from(User).where(*filters))
    ).scalar_one()


async def list_users_page(
    db: AsyncSession,
    *,
    tenant_id: str,
    page: int,
    page_size: int,
    search: str | None = None,
    status: str | None = None,
) -> tuple[list[User], int]:
    filters = [User.tenant_id == tenant_id, User.deleted_at.is_(None)]
    if search:
        like = f"%{search}%"
        filters.append(or_(User.username.ilike(like), User.full_name.ilike(like)))
    if status == "active":
        filters.append(User.is_active.is_(True))
    elif status == "inactive":
        filters.append(User.is_active.is_(False))

    total = await count_users(db, *filters)
    result = await db.execute(
        select(User)
        .where(*filters)
        .options(user_with_roles_options())
        .order_by(User.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return list(result.scalars().all()), total


async def get_by_username(
    db: AsyncSession, *, tenant_id: str, username: str, with_permissions: bool = False
) -> User | None:
    opts = user_with_permissions_options() if with_permissions else ()
    stmt = select(User).where(
        User.username == username,
        User.tenant_id == tenant_id,
        User.deleted_at.is_(None),
    )
    if with_permissions:
        stmt = stmt.options(opts)
    return (await db.execute(stmt)).scalar_one_or_none()


async def get_by_id(
    db: AsyncSession,
    *,
    user_id: str,
    tenant_id: str,
    with_roles: bool = False,
    with_permissions: bool = False,
    active_only: bool = False,
) -> User | None:
    filters = [
        User.id == user_id,
        User.tenant_id == tenant_id,
        User.deleted_at.is_(None),
    ]
    if active_only:
        filters.append(User.is_active.is_(True))

    stmt = select(User).where(*filters)
    if with_permissions:
        stmt = stmt.options(user_with_permissions_options())
    elif with_roles:
        stmt = stmt.options(user_with_roles_options())
    return (await db.execute(stmt)).scalar_one_or_none()


async def find_active_username(
    db: AsyncSession, *, tenant_id: str, username: str
) -> User | None:
    return (
        await db.execute(
            select(User).where(
                User.tenant_id == tenant_id,
                User.username == username,
                User.deleted_at.is_(None),
            )
        )
    ).scalar_one_or_none()


async def count_active_in_tenant(db: AsyncSession, tenant_id: str) -> int:
    return await count_users(
        db, User.tenant_id == tenant_id, User.deleted_at.is_(None)
    )


async def list_recent(db: AsyncSession, tenant_id: str, *, limit: int = 4) -> list[User]:
    result = await db.execute(
        select(User)
        .where(User.tenant_id == tenant_id, User.deleted_at.is_(None))
        .order_by(User.created_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


async def add_user(db: AsyncSession, user: User) -> User:
    db.add(user)
    await db.flush()
    return user


async def add_user_roles(
    db: AsyncSession, *, user_id: str, tenant_id: str, role_ids: list[str]
) -> None:
    for rid in role_ids:
        db.add(UserRole(user_id=user_id, role_id=rid, tenant_id=tenant_id))


async def replace_user_roles(
    db: AsyncSession, user: User, *, tenant_id: str, role_ids: list[str]
) -> None:
    for ur in list(user.user_roles):
        await db.delete(ur)
    await db.flush()
    await add_user_roles(db, user_id=user.id, tenant_id=tenant_id, role_ids=role_ids)


async def soft_delete(db: AsyncSession, user: User) -> None:
    user.deleted_at = utcnow()
    user.is_active = False
