from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.timeutil import utcnow
from app.models import FilmComment, WatchlistItem
from app.repositories import engagement as eng_repo
from app.repositories import film as film_repo
from app.schemas.film import CommentCreate, ProgressUpdate, RatingUpdate
from app.services.film_mapper import serialize_film_card
from app.services.system_log import write_system_log


async def _require_visible_film(db: AsyncSession, slug: str):
    film = await film_repo.get_by_slug(db, slug=slug)
    if not film or film.is_hidden:
        raise HTTPException(status_code=404, detail="Không tìm thấy phim")
    return film


async def add_to_watchlist(db: AsyncSession, *, user_id: str, slug: str) -> dict:
    film = await _require_visible_film(db, slug)
    existing = await eng_repo.get_watchlist_item(db, user_id=user_id, film_id=film.id)
    if not existing:
        await eng_repo.add_watchlist(
            db, WatchlistItem(user_id=user_id, film_id=film.id)
        )
        await db.commit()
    return {"success": True, "message": "Đã thêm vào tủ phim"}


async def remove_from_watchlist(db: AsyncSession, *, user_id: str, slug: str) -> dict:
    film = await film_repo.get_by_slug(db, slug=slug)
    if not film:
        raise HTTPException(status_code=404, detail="Không tìm thấy phim")
    existing = await eng_repo.get_watchlist_item(db, user_id=user_id, film_id=film.id)
    if existing:
        await eng_repo.delete_watchlist(db, existing)
        await db.commit()
    return {"success": True, "message": "Đã xóa khỏi tủ phim"}


async def list_watchlist(
    db: AsyncSession, *, user_id: str, page: int = 1, page_size: int = 24
) -> dict:
    rows, total = await eng_repo.list_watchlist(
        db, user_id=user_id, page=page, page_size=page_size
    )
    return {
        "success": True,
        "data": [
            serialize_film_card(r.film)
            for r in rows
            if r.film and not r.film.is_hidden
        ],
        "total": total,
        "page": page,
        "pageSize": page_size,
    }


async def save_progress(
    db: AsyncSession, *, user_id: str, body: ProgressUpdate
) -> dict:
    film = await _require_visible_film(db, body.slug)
    item = await eng_repo.upsert_progress(
        db,
        user_id=user_id,
        film_id=film.id,
        episode_slug=body.episode_slug,
        episode_name=body.episode_name,
        server_name=body.server_name,
        position_sec=body.position_sec,
    )
    await db.commit()
    return {
        "success": True,
        "data": {
            "slug": film.source_slug,
            "episodeSlug": item.episode_slug,
            "episodeName": item.episode_name,
            "serverName": item.server_name,
            "positionSec": item.position_sec,
            "updatedAt": item.updated_at,
        },
    }


async def list_continue(db: AsyncSession, *, user_id: str) -> dict:
    rows = await eng_repo.list_continue(db, user_id=user_id)
    return {
        "success": True,
        "data": [
            {
                "slug": r.film.source_slug,
                "episodeSlug": r.episode_slug,
                "episodeName": r.episode_name,
                "serverName": r.server_name,
                "positionSec": r.position_sec,
                "updatedAt": r.updated_at,
                "film": serialize_film_card(r.film),
            }
            for r in rows
            if r.film
        ],
    }


async def rate_film(
    db: AsyncSession, *, user_id: str, slug: str, body: RatingUpdate
) -> dict:
    film = await _require_visible_film(db, slug)
    await eng_repo.upsert_rating(
        db, user_id=user_id, film_id=film.id, score=body.score
    )
    avg, count = await eng_repo.rating_stats(db, film_id=film.id)
    await film_repo.update_rating_aggregate(db, film_id=film.id, avg=avg, count=count)
    await db.commit()
    return {
        "success": True,
        "data": {"score": body.score, "avgRating": round(avg, 1), "ratingCount": count},
    }


async def list_comments(
    db: AsyncSession, *, slug: str, page: int = 1, page_size: int = 20
) -> dict:
    film = await _require_visible_film(db, slug)
    rows, total = await eng_repo.list_comments(
        db, film_id=film.id, page=page, page_size=page_size
    )
    return {
        "success": True,
        "data": [
            {
                "id": c.id,
                "body": c.body,
                "username": c.user.username if c.user else "user",
                "fullName": c.user.full_name if c.user else None,
                "avatar": c.user.avatar if c.user else None,
                "createdAt": c.created_at,
            }
            for c in rows
        ],
        "total": total,
        "page": page,
        "pageSize": page_size,
    }


async def add_comment(
    db: AsyncSession, *, user_id: str, slug: str, body: CommentCreate
) -> dict:
    film = await _require_visible_film(db, slug)
    text = body.body.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Nội dung trống")
    comment = await eng_repo.add_comment(
        db, FilmComment(user_id=user_id, film_id=film.id, body=text)
    )
    await db.commit()
    comment = await eng_repo.get_comment(db, comment_id=comment.id)
    assert comment is not None
    return {
        "success": True,
        "data": {
            "id": comment.id,
            "body": comment.body,
            "username": comment.user.username if comment.user else "user",
            "createdAt": comment.created_at,
        },
    }


async def admin_list_comments(
    db: AsyncSession, *, page: int = 1, page_size: int = 20
) -> dict:
    rows, total = await eng_repo.list_admin_comments(db, page=page, page_size=page_size)
    return {
        "success": True,
        "data": [
            {
                "id": c.id,
                "body": c.body,
                "username": c.user.username if c.user else "user",
                "createdAt": c.created_at,
                "isHidden": c.is_hidden,
                "filmSlug": c.film.source_slug if c.film else None,
                "filmName": c.film.name if c.film else None,
            }
            for c in rows
        ],
        "total": total,
        "page": page,
        "pageSize": page_size,
    }


async def admin_moderate_comment(
    db: AsyncSession,
    *,
    actor_id: str,
    comment_id: str,
    is_hidden: bool | None = None,
    soft_delete: bool = False,
) -> dict:
    comment = await eng_repo.get_comment(db, comment_id=comment_id)
    if not comment or comment.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Không tìm thấy bình luận")
    if soft_delete:
        comment.deleted_at = utcnow()
    elif is_hidden is not None:
        comment.is_hidden = is_hidden
    await db.commit()
    await write_system_log(
        db,
        user_id=actor_id,
        action="MODERATE_COMMENT",
        resource="Comment",
        details=f"id={comment_id} hidden={comment.is_hidden} deleted={bool(comment.deleted_at)}",
    )
    return {"success": True, "message": "Đã cập nhật bình luận"}
