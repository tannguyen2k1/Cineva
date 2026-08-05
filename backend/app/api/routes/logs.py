from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, require_permission
from app.db.session import get_db
from app.services import catalog as catalog_service

router = APIRouter(prefix="/logs", tags=["Logs"])


@router.get("")
async def list_logs(
    page: int = 1,
    pageSize: int = 10,
    search: str | None = None,
    resource: str | None = None,
    action: str | None = None,
    startDate: str | None = None,
    endDate: str | None = None,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("read:logs")),
):
    return await catalog_service.list_logs(
        db,
        page=page,
        page_size=pageSize,
        search=search,
        resource=resource,
        action=action,
        start_date=startDate,
        end_date=endDate,
    )
