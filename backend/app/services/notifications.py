from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories import notifications as notif_repo


def serialize_notification(n) -> dict:
    return {
        "id": n.id,
        "kind": n.kind,
        "title": n.title,
        "body": n.body,
        "linkUrl": n.link_url,
        "isRead": n.is_read,
        "createdAt": n.created_at,
        "actor": (
            {
                "username": n.actor.username,
                "fullName": n.actor.full_name,
                "avatar": n.actor.avatar,
            }
            if n.actor
            else None
        ),
        "film": (
            {
                "slug": n.film.source_slug,
                "name": n.film.name,
                "thumbUrl": n.film.thumb_url,
                "posterUrl": n.film.poster_url,
            }
            if n.film
            else None
        ),
    }


async def list_mine(
    db: AsyncSession, *, user_id: str, page: int = 1, page_size: int = 20
) -> dict:
    rows, total = await notif_repo.list_notifications(
        db, user_id=user_id, page=page, page_size=page_size
    )
    return {
        "success": True,
        "data": [serialize_notification(n) for n in rows],
        "total": total,
        "page": page,
        "pageSize": page_size,
        "unreadCount": await notif_repo.unread_count(db, user_id=user_id),
    }


async def unread_count(db: AsyncSession, *, user_id: str) -> dict:
    return {
        "success": True,
        "data": {"unreadCount": await notif_repo.unread_count(db, user_id=user_id)},
    }


async def mark_one_read(
    db: AsyncSession, *, user_id: str, notification_id: str
) -> dict:
    item = await notif_repo.get_notification(
        db, user_id=user_id, notification_id=notification_id
    )
    if not item:
        raise HTTPException(status_code=404, detail="Không tìm thấy thông báo")
    await notif_repo.mark_read(db, notification=item)
    await db.commit()
    return {"success": True, "message": "Đã đọc"}


async def mark_all_read(db: AsyncSession, *, user_id: str) -> dict:
    count = await notif_repo.mark_all_read(db, user_id=user_id)
    await db.commit()
    return {"success": True, "data": {"updated": count}}
