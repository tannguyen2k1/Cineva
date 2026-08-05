from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, require_permission
from app.db.session import get_db
from app.services import catalog as catalog_service

router = APIRouter(tags=["Permissions"])


@router.get("/permissions")
async def list_permissions(
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("read:roles")),
):
    return await catalog_service.list_permission_catalog(db)
