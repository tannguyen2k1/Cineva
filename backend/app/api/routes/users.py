from fastapi import APIRouter, Depends, File, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, get_current_user, require_permission
from app.db.session import get_db
from app.schemas import ProfileUpdate, UserCreate, UserUpdate
from app.services import users as users_service

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("")
async def list_users(
    page: int = 1,
    pageSize: int = 10,
    search: str | None = None,
    status: str | None = None,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("read:users")),
):
    return await users_service.list_users(
        db, current.tenant_id, page=page, page_size=pageSize, search=search, status=status
    )


@router.post("")
async def create_user(
    body: UserCreate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("create:users")),
):
    return await users_service.create_user(db, current.tenant_id, current.id, body)


@router.put("/profile")
async def update_profile(
    body: ProfileUpdate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await users_service.update_profile(db, current.id, current.tenant_id, body)


@router.post("/avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await users_service.upload_avatar(db, current.id, current.tenant_id, file)


@router.put("/{user_id}")
async def update_user(
    user_id: str,
    body: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("update:users")),
):
    return await users_service.update_user(db, current.tenant_id, current.id, user_id, body)


@router.delete("/{user_id}")
async def delete_user(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("delete:users")),
):
    return await users_service.delete_user(db, current.tenant_id, current.id, user_id)
