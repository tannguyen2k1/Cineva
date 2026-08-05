from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, require_permission
from app.db.session import get_db
from app.schemas import TenantCreate, TenantUpdate
from app.services import tenants as tenants_service

router = APIRouter(prefix="/tenants", tags=["Tenants"])


@router.get("")
async def list_tenants(
    page: int = 1,
    pageSize: int = 10,
    search: str | None = None,
    status: str | None = None,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("read:tenants")),
):
    return await tenants_service.list_tenants(
        db, page=page, page_size=pageSize, search=search, status=status
    )


@router.post("")
async def create_tenant(
    body: TenantCreate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("create:tenants")),
):
    return await tenants_service.create_tenant(db, current.tenant_id, current.id, body)


@router.put("/{tenant_id}")
async def update_tenant(
    tenant_id: str,
    body: TenantUpdate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("update:tenants")),
):
    return await tenants_service.update_tenant(
        db, current.tenant_id, current.id, tenant_id, body
    )


@router.delete("/{tenant_id}")
async def delete_tenant(
    tenant_id: str,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("delete:tenants")),
):
    return await tenants_service.delete_tenant(db, current.tenant_id, current.id, tenant_id)
