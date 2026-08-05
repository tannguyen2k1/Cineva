from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, require_permission
from app.db.session import get_db
from app.services import catalog as catalog_service

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/stats")
async def dashboard_stats(
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("read:dashboard")),
):
    return await catalog_service.dashboard_stats(db, current.tenant_id)
