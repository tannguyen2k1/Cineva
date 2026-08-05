from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Tenant


async def count_tenants(db: AsyncSession, *filters) -> int:
    return (
        await db.execute(select(func.count()).select_from(Tenant).where(*filters))
    ).scalar_one()


async def list_tenants_page(
    db: AsyncSession,
    *,
    page: int,
    page_size: int,
    search: str | None = None,
    status: str | None = None,
) -> tuple[list[Tenant], int]:
    filters = [Tenant.deleted_at.is_(None)]
    if search:
        like = f"%{search}%"
        filters.append(or_(Tenant.name.ilike(like), Tenant.domain.ilike(like)))
    if status == "active":
        filters.append(Tenant.is_active.is_(True))
    elif status == "inactive":
        filters.append(Tenant.is_active.is_(False))

    total = await count_tenants(db, *filters)
    result = await db.execute(
        select(Tenant)
        .where(*filters)
        .options(selectinload(Tenant.users))
        .order_by(Tenant.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return list(result.scalars().all()), total


async def get_by_id(
    db: AsyncSession, tenant_id: str, *, with_users: bool = False
) -> Tenant | None:
    stmt = select(Tenant).where(Tenant.id == tenant_id, Tenant.deleted_at.is_(None))
    if with_users:
        stmt = stmt.options(selectinload(Tenant.users))
    return (await db.execute(stmt)).scalar_one_or_none()


async def get_by_name(db: AsyncSession, name: str) -> Tenant | None:
    return (
        await db.execute(
            select(Tenant).where(Tenant.name == name, Tenant.deleted_at.is_(None))
        )
    ).scalar_one_or_none()


async def find_by_name(
    db: AsyncSession, name: str, *, exclude_id: str | None = None
) -> Tenant | None:
    filters = [Tenant.name == name, Tenant.deleted_at.is_(None)]
    if exclude_id:
        filters.append(Tenant.id != exclude_id)
    return (await db.execute(select(Tenant).where(*filters))).scalar_one_or_none()


async def find_by_domain(
    db: AsyncSession, domain: str, *, exclude_id: str | None = None
) -> Tenant | None:
    filters = [Tenant.domain == domain]
    if exclude_id:
        filters.append(Tenant.id != exclude_id)
    return (await db.execute(select(Tenant).where(*filters))).scalar_one_or_none()


async def count_active(db: AsyncSession) -> int:
    return await count_tenants(db, Tenant.deleted_at.is_(None))


async def add_tenant(db: AsyncSession, tenant: Tenant) -> Tenant:
    db.add(tenant)
    await db.flush()
    return tenant


async def soft_delete(db: AsyncSession, tenant: Tenant) -> None:
    tenant.deleted_at = datetime.now(timezone.utc)
    tenant.is_active = False
    if tenant.domain:
        tenant.domain = f"{tenant.domain}__deleted__{tenant.id[:8]}"


def active_user_count(tenant: Tenant) -> int:
    return sum(1 for u in tenant.users if u.deleted_at is None)
