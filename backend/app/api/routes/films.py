from fastapi import APIRouter, Depends, Query, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, get_current_user, get_optional_user, require_permission
from app.db.session import get_db
from app.schemas.film import (
    BannerCreate,
    BannerUpdate,
    CommentCreate,
    FeaturedCreate,
    FilmHideUpdate,
    ProgressUpdate,
    RatingUpdate,
    RegisterRequest,
)
from app.services import auth as auth_service
from app.services import cms as cms_service
from app.services import engagement as engagement_service
from app.services import film_sync as film_sync_service
from app.services import films as films_service
from app.services import notifications as notifications_service
from app.services import traffic as traffic_service

public_router = APIRouter(prefix="/public", tags=["Public Films"])
me_router = APIRouter(prefix="/me", tags=["My Films"])
admin_films_router = APIRouter(prefix="/admin", tags=["Admin Films"])


@public_router.post("/traffic/hit", summary="Record a public page view")
async def public_traffic_hit(
    request: Request,
    body: traffic_service.TrafficHitBody | None = None,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser | None = Depends(get_optional_user),
):
    return await traffic_service.hit(
        db,
        request=request,
        body=body,
        user_id=current.id if current else None,
    )


@public_router.get("/home")
async def public_home(db: AsyncSession = Depends(get_db)):
    return await films_service.home(db)


@public_router.get("/films")
async def public_list_films(
    page: int = Query(1, ge=1),
    pageSize: int = Query(24, ge=1, le=100),
    q: str | None = None,
    genre: str | None = None,
    country: str | None = None,
    year: str | None = None,
    type: str | None = None,
    sort: str = Query("newest", pattern="^(newest|name|year)$"),
    db: AsyncSession = Depends(get_db),
):
    return await films_service.list_films(
        db,
        page=page,
        page_size=pageSize,
        q=q,
        genre=genre,
        country=country,
        year=year,
        film_type=type,
        sort=sort,
    )


@public_router.get("/films/{slug}")
async def public_film_detail(
    slug: str,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser | None = Depends(get_optional_user),
):
    return await films_service.get_detail(
        db, slug=slug, user_id=current.id if current else None
    )


@public_router.get("/taxonomies")
async def public_taxonomies(db: AsyncSession = Depends(get_db)):
    return await films_service.taxonomies(db)


@public_router.get("/films/{slug}/comments")
async def public_list_comments(
    slug: str,
    page: int = Query(1, ge=1),
    pageSize: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    return await engagement_service.list_comments(
        db, slug=slug, page=page, page_size=pageSize
    )


@public_router.post("/films/{slug}/comments")
async def public_add_comment(
    slug: str,
    body: CommentCreate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await engagement_service.add_comment(
        db, user_id=current.id, slug=slug, body=body
    )


@me_router.post("/watchlist/{slug}")
async def me_add_watchlist(
    slug: str,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await engagement_service.add_to_watchlist(db, user_id=current.id, slug=slug)


@me_router.delete("/watchlist/{slug}")
async def me_remove_watchlist(
    slug: str,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await engagement_service.remove_from_watchlist(
        db, user_id=current.id, slug=slug
    )


@me_router.get("/watchlist")
async def me_list_watchlist(
    page: int = Query(1, ge=1),
    pageSize: int = Query(24, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await engagement_service.list_watchlist(
        db, user_id=current.id, page=page, page_size=pageSize
    )


@me_router.post("/follows/{slug}")
async def me_follow_film(
    slug: str,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await engagement_service.follow_film(db, user_id=current.id, slug=slug)


@me_router.delete("/follows/{slug}")
async def me_unfollow_film(
    slug: str,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await engagement_service.unfollow_film(db, user_id=current.id, slug=slug)


@me_router.put("/progress")
async def me_save_progress(
    body: ProgressUpdate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await engagement_service.save_progress(db, user_id=current.id, body=body)


@me_router.get("/continue")
async def me_continue(
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await engagement_service.list_continue(db, user_id=current.id)


@me_router.get("/notifications")
async def me_list_notifications(
    page: int = Query(1, ge=1),
    pageSize: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await notifications_service.list_mine(
        db, user_id=current.id, page=page, page_size=pageSize
    )


@me_router.get("/notifications/unread-count")
async def me_notifications_unread(
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await notifications_service.unread_count(db, user_id=current.id)


@me_router.post("/notifications/read-all")
async def me_notifications_read_all(
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await notifications_service.mark_all_read(db, user_id=current.id)


@me_router.put("/notifications/{notification_id}/read")
async def me_notification_read(
    notification_id: str,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await notifications_service.mark_one_read(
        db, user_id=current.id, notification_id=notification_id
    )


@me_router.put("/ratings/{slug}")
async def me_rate(
    slug: str,
    body: RatingUpdate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(get_current_user),
):
    return await engagement_service.rate_film(
        db, user_id=current.id, slug=slug, body=body
    )


@admin_films_router.post("/sync/run")
async def admin_sync_run(
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("create:sync")),
):
    return await film_sync_service.run_incremental_sync(db, actor_id=current.id)


@admin_films_router.post("/sync/catalog")
async def admin_sync_catalog(
    pagesPerSource: int = 2,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("create:sync")),
):
    return await film_sync_service.run_catalog_sync(
        db, actor_id=current.id, pages_per_source=max(1, min(pagesPerSource, 5))
    )


@admin_films_router.get("/sync/runs")
async def admin_sync_runs(
    page: int = Query(1, ge=1),
    pageSize: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("read:sync")),
):
    return await film_sync_service.list_sync_runs(db, page=page, page_size=pageSize)


@admin_films_router.get("/films")
async def admin_list_films(
    page: int = Query(1, ge=1),
    pageSize: int = Query(24, ge=1, le=100),
    q: str | None = None,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("read:films")),
):
    return await films_service.list_films(
        db, page=page, page_size=pageSize, q=q, include_hidden=True
    )


@admin_films_router.patch("/films/{slug}")
async def admin_hide_film(
    slug: str,
    body: FilmHideUpdate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("update:films")),
):
    return await films_service.admin_set_hidden(
        db, actor_id=current.id, slug=slug, is_hidden=body.is_hidden
    )


@admin_films_router.get("/banners")
async def admin_list_banners(
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("read:banners")),
):
    return await cms_service.admin_list_banners(db)


@admin_films_router.post("/banners")
async def admin_create_banner(
    body: BannerCreate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("create:banners")),
):
    return await cms_service.create_banner(db, actor_id=current.id, body=body)


@admin_films_router.patch("/banners/{banner_id}")
async def admin_update_banner(
    banner_id: str,
    body: BannerUpdate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("update:banners")),
):
    return await cms_service.update_banner(
        db, actor_id=current.id, banner_id=banner_id, body=body
    )


@admin_films_router.delete("/banners/{banner_id}")
async def admin_delete_banner(
    banner_id: str,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("delete:banners")),
):
    return await cms_service.delete_banner(db, actor_id=current.id, banner_id=banner_id)


@admin_films_router.get("/featured")
async def admin_list_featured(
    section: str | None = None,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("read:featured")),
):
    return await cms_service.admin_list_featured(db, section=section)


@admin_films_router.post("/featured")
async def admin_create_featured(
    body: FeaturedCreate,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("create:featured")),
):
    return await cms_service.create_featured(db, actor_id=current.id, body=body)


@admin_films_router.delete("/featured/{featured_id}")
async def admin_delete_featured(
    featured_id: str,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("delete:featured")),
):
    return await cms_service.delete_featured(
        db, actor_id=current.id, featured_id=featured_id
    )


@admin_films_router.get("/comments")
async def admin_list_comments(
    page: int = Query(1, ge=1),
    pageSize: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("read:comments")),
):
    return await engagement_service.admin_list_comments(
        db, page=page, page_size=pageSize
    )


@admin_films_router.patch("/comments/{comment_id}")
async def admin_hide_comment(
    comment_id: str,
    isHidden: bool = Query(...),
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("update:comments")),
):
    return await engagement_service.admin_moderate_comment(
        db, actor_id=current.id, comment_id=comment_id, is_hidden=isHidden
    )


@admin_films_router.delete("/comments/{comment_id}")
async def admin_delete_comment(
    comment_id: str,
    db: AsyncSession = Depends(get_db),
    current: CurrentUser = Depends(require_permission("delete:comments")),
):
    return await engagement_service.admin_moderate_comment(
        db, actor_id=current.id, comment_id=comment_id, soft_delete=True
    )


auth_register_router = APIRouter(prefix="/auth", tags=["Auth"])


@auth_register_router.post("/register", summary="Public member registration")
async def register(
    body: RegisterRequest,
    response: Response,
    db: AsyncSession = Depends(get_db),
):
    return await auth_service.register(db, body, response)
