from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, require_permission
from app.db.session import get_db
from app.schemas import RoleCreate, RolePermissionsUpdate, RoleUpdate
from app.services import roles as roles_service

router = APIRouter(prefix="/roles", tags=["Roles"])


@router.get("")
async def list_roles(
    page: int = 1,
    pageSize: int = 10,
    search: str | None = None,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("read:roles")),
):
    return await roles_service.list_roles(
        db, page=page, page_size=pageSize, search=search
    )


@router.post("")
async def create_role(
    body: RoleCreate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("create:roles")),
):
    return await roles_service.create_role(db, current.id, body)


@router.put("/{role_id}")
async def update_role(
    role_id: str,
    body: RoleUpdate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("update:roles")),
):
    return await roles_service.update_role(db, current.id, role_id, body)


@router.delete("/{role_id}")
async def delete_role(
    role_id: str,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("delete:roles")),
):
    return await roles_service.delete_role(db, current.id, role_id)


@router.get("/{role_id}/permissions")
async def get_role_permissions(
    role_id: str,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("read:roles")),
):
    return await roles_service.get_role_permissions(db, role_id)


@router.put("/{role_id}/permissions")
async def update_role_permissions(
    role_id: str,
    body: RolePermissionsUpdate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("update:roles")),
):
    return await roles_service.update_role_permissions(
        db, current.id, role_id, body
    )
