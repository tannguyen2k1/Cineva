from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.timeutil import utcnow
from app.models import FilmComment, FilmFollow, WatchlistItem
from app.repositories import engagement as eng_repo
from app.repositories import film as film_repo
from app.repositories import notifications as notif_repo
from app.schemas.film import CommentCreate, ProgressUpdate, RatingUpdate
from app.services.film_mapper import serialize_film_card
from app.services.system_log import write_system_log


def _serialize_comment(c: FilmComment, *, with_replies: bool = False) -> dict:
    data = {
        "id": c.id,
        "body": c.body,
        "username": c.user.username if c.user else "user",
        "fullName": c.user.full_name if c.user else None,
        "avatar": c.user.avatar if c.user else None,
        "createdAt": c.created_at,
        "parentId": c.parent_id,
    }
    if with_replies:
        replies = [
            _serialize_comment(r)
            for r in sorted(c.replies or [], key=lambda x: x.created_at)
            if r.deleted_at is None and not r.is_hidden
        ]
        data["replies"] = replies
    return data


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


async def follow_film(db: AsyncSession, *, user_id: str, slug: str) -> dict:
    film = await _require_visible_film(db, slug)
    existing = await eng_repo.get_follow(db, user_id=user_id, film_id=film.id)
    if not existing:
        await eng_repo.add_follow(db, FilmFollow(user_id=user_id, film_id=film.id))
        await db.commit()
    return {"success": True, "message": "Đã theo dõi phim"}


async def unfollow_film(db: AsyncSession, *, user_id: str, slug: str) -> dict:
    film = await film_repo.get_by_slug(db, slug=slug)
    if not film:
        raise HTTPException(status_code=404, detail="Không tìm thấy phim")
    existing = await eng_repo.get_follow(db, user_id=user_id, film_id=film.id)
    if existing:
        await eng_repo.delete_follow(db, existing)
        await db.commit()
    return {"success": True, "message": "Đã bỏ theo dõi"}


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
        "data": [_serialize_comment(c, with_replies=True) for c in rows],
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

    parent_id = body.parent_id
    parent = None
    notify_user_id: str | None = None
    if parent_id:
        parent = await eng_repo.get_comment(db, comment_id=parent_id)
        if (
            not parent
            or parent.deleted_at is not None
            or parent.film_id != film.id
            or parent.is_hidden
        ):
            raise HTTPException(status_code=404, detail="Không tìm thấy bình luận")
        # Notify the author being replied to (even if we flatten nesting)
        if parent.user_id != user_id:
            notify_user_id = parent.user_id
        # One-level threads: reply-to-reply attaches to the root parent
        if parent.parent_id:
            root = await eng_repo.get_comment(db, comment_id=parent.parent_id)
            if root:
                parent_id = root.id
                parent = root

    comment = await eng_repo.add_comment(
        db,
        FilmComment(
            user_id=user_id,
            film_id=film.id,
            parent_id=parent_id,
            body=text,
        ),
    )
    await db.flush()

    if notify_user_id and parent:
        actor_name = "Ai đó"
        comment = await eng_repo.get_comment(db, comment_id=comment.id)
        if comment and comment.user:
            actor_name = comment.user.full_name or comment.user.username
        await notif_repo.create_notification(
            db,
            user_id=notify_user_id,
            kind="comment_reply",
            title=f"{actor_name} đã trả lời bình luận của bạn",
            body=text[:180],
            link_url=f"/phim/{film.source_slug}",
            ref_key=f"reply:{comment.id if comment else parent_id}",
            actor_id=user_id,
            film_id=film.id,
            comment_id=comment.id if comment else None,
        )

    await db.commit()
    comment = await eng_repo.get_comment(db, comment_id=comment.id)
    assert comment is not None
    return {
        "success": True,
        "data": _serialize_comment(comment),
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
