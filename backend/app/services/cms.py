from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Banner, FeaturedFilm
from app.repositories import cms as cms_repo
from app.repositories import film as film_repo
from app.schemas.film import BannerCreate, BannerUpdate, FeaturedCreate
from app.services.film_mapper import serialize_film_card
from app.services.system_log import write_system_log


def _banner_out(b: Banner, *, admin: bool = False) -> dict:
    data = {
        "id": b.id,
        "title": b.title,
        "imageUrl": b.image_url,
        "linkUrl": b.link_url,
        "filmSlug": b.film_slug,
        "sortOrder": b.sort_order,
    }
    if admin:
        data["isActive"] = b.is_active
        data["startsAt"] = b.starts_at
        data["endsAt"] = b.ends_at
    return data


async def admin_list_banners(db: AsyncSession) -> dict:
    rows = await cms_repo.list_all_banners(db)
    return {"success": True, "data": [_banner_out(b, admin=True) for b in rows]}


async def create_banner(db: AsyncSession, *, actor_id: str, body: BannerCreate) -> dict:
    banner = Banner(
        title=body.title,
        image_url=body.image_url,
        link_url=body.link_url,
        film_slug=body.film_slug,
        sort_order=body.sort_order,
        is_active=body.is_active,
        starts_at=body.starts_at,
        ends_at=body.ends_at,
    )
    await cms_repo.add_banner(db, banner)
    await db.commit()
    await write_system_log(
        db, user_id=actor_id, action="CREATE_BANNER", resource="Banner", details=banner.id
    )
    return {"success": True, "data": _banner_out(banner, admin=True)}


async def update_banner(
    db: AsyncSession, *, actor_id: str, banner_id: str, body: BannerUpdate
) -> dict:
    banner = await cms_repo.get_banner(db, banner_id=banner_id)
    if not banner:
        raise HTTPException(status_code=404, detail="Không tìm thấy banner")
    data = body.model_dump(by_alias=False, exclude_unset=True)
    field_map = {
        "title": "title",
        "image_url": "image_url",
        "link_url": "link_url",
        "film_slug": "film_slug",
        "sort_order": "sort_order",
        "is_active": "is_active",
        "starts_at": "starts_at",
        "ends_at": "ends_at",
    }
    for key, attr in field_map.items():
        if key in data:
            setattr(banner, attr, data[key])
    await db.commit()
    await write_system_log(
        db, user_id=actor_id, action="UPDATE_BANNER", resource="Banner", details=banner_id
    )
    return {"success": True, "data": _banner_out(banner, admin=True)}


async def delete_banner(db: AsyncSession, *, actor_id: str, banner_id: str) -> dict:
    banner = await cms_repo.get_banner(db, banner_id=banner_id)
    if not banner:
        raise HTTPException(status_code=404, detail="Không tìm thấy banner")
    await cms_repo.delete_banner(db, banner)
    await db.commit()
    await write_system_log(
        db, user_id=actor_id, action="DELETE_BANNER", resource="Banner", details=banner_id
    )
    return {"success": True, "message": "Đã xóa banner"}


async def admin_list_featured(db: AsyncSession, *, section: str | None = None) -> dict:
    rows = await cms_repo.list_featured(db, section=section)
    return {
        "success": True,
        "data": [
            {
                "id": f.id,
                "section": f.section,
                "sortOrder": f.sort_order,
                "film": serialize_film_card(f.film) if f.film else None,
            }
            for f in rows
        ],
    }


async def create_featured(
    db: AsyncSession, *, actor_id: str, body: FeaturedCreate
) -> dict:
    film = await film_repo.get_by_slug(db, slug=body.film_slug)
    if not film:
        raise HTTPException(status_code=404, detail="Không tìm thấy phim")
    item = FeaturedFilm(
        film_id=film.id, section=body.section, sort_order=body.sort_order
    )
    await cms_repo.add_featured(db, item)
    await db.commit()
    await write_system_log(
        db,
        user_id=actor_id,
        action="CREATE_FEATURED",
        resource="Featured",
        details=f"{body.film_slug}:{body.section}",
    )
    film = await film_repo.get_by_slug(db, slug=body.film_slug, with_taxonomy=True)
    return {
        "success": True,
        "data": {
            "id": item.id,
            "section": item.section,
            "sortOrder": item.sort_order,
            "film": serialize_film_card(film) if film else None,
        },
    }


async def delete_featured(db: AsyncSession, *, actor_id: str, featured_id: str) -> dict:
    item = await cms_repo.get_featured(db, featured_id=featured_id)
    if not item:
        raise HTTPException(status_code=404, detail="Không tìm thấy mục nổi bật")
    await cms_repo.delete_featured(db, item)
    await db.commit()
    await write_system_log(
        db, user_id=actor_id, action="DELETE_FEATURED", resource="Featured", details=featured_id
    )
    return {"success": True, "message": "Đã gỡ khỏi nổi bật"}
