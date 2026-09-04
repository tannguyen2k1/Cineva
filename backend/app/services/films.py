from __future__ import annotations

import time
from typing import Any

import httpx
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.timeutil import utcnow
from app.models import Film
from app.repositories import cms as cms_repo
from app.repositories import engagement as eng_repo
from app.repositories import film as film_repo
from app.services.film_mapper import (
    apply_detail_to_film,
    serialize_film_card,
    split_taxonomy,
)
from app.services.nguonc_client import get_nguonc_client
from app.services.system_log import write_system_log

_detail_cache: dict[str, tuple[float, dict[str, Any]]] = {}


async def list_films(
    db: AsyncSession,
    *,
    page: int = 1,
    page_size: int = 24,
    q: str | None = None,
    genre: str | None = None,
    country: str | None = None,
    year: str | None = None,
    film_type: str | None = None,
    include_hidden: bool = False,
) -> dict:
    films, total = await film_repo.list_films_page(
        db,
        page=page,
        page_size=page_size,
        q=q,
        genre=genre,
        country=country,
        year=year,
        film_type=film_type,
        include_hidden=include_hidden,
    )
    return {
        "success": True,
        "data": [serialize_film_card(f, include_hidden=include_hidden) for f in films],
        "total": total,
        "page": page,
        "pageSize": page_size,
    }


async def taxonomies(db: AsyncSession) -> dict:
    genres = await film_repo.list_genres(db)
    countries = await film_repo.list_countries(db)
    types = await film_repo.list_film_types(db)
    years = await film_repo.list_years(db)
    return {
        "success": True,
        "data": {
            "genres": [{"slug": g.slug, "name": g.name} for g in genres],
            "countries": [{"slug": c.slug, "name": c.name} for c in countries],
            "types": [{"slug": t.slug, "name": t.name} for t in types],
            "years": years,
        },
    }


# Curated topic cards for home (RoPhim-style discovery)
HOME_TOPICS: list[dict] = [
    {"slug": "khoa-hoc-vien-tuong", "name": "Viễn Tưởng", "href": "/phim?genre=khoa-hoc-vien-tuong", "tone": "violet"},
    {"slug": "thai-lan", "name": "Thái Lan", "href": "/phim?country=thai-lan", "tone": "rose"},
    {"slug": "dang-chieu", "name": "Chiếu Rạp", "href": "/phim?type=dang-chieu", "tone": "amber"},
    {"slug": "kinh-di", "name": "Kinh Dị", "href": "/phim?genre=kinh-di", "tone": "crimson"},
    {"slug": "co-trang", "name": "Cổ Trang", "href": "/phim?genre=co-trang", "tone": "gold"},
    {"slug": "chien-tranh", "name": "Chiến Tranh", "href": "/phim?genre=chien-tranh", "tone": "slate"},
]


# Curated home rails (newest is rendered separately on FE)
HOME_SECTIONS: list[tuple[str, str, str, str]] = [
    # kind, slug, title, href
    ("type", "phim-bo", "Phim Bộ", "/phim?type=phim-bo"),
    ("type", "phim-le", "Phim Lẻ", "/phim?type=phim-le"),
    ("genre", "hanh-dong", "Hành Động", "/phim?genre=hanh-dong"),
    ("genre", "tinh-cam", "Tình Cảm", "/phim?genre=tinh-cam"),
    ("country", "han-quoc", "Hàn Quốc", "/phim?country=han-quoc"),
    ("type", "dang-chieu", "Đang Chiếu", "/phim?type=dang-chieu"),
]

# Skip sparse rails that look empty on the home page
MIN_HOME_SECTION_ITEMS = 6


async def home(db: AsyncSession) -> dict:
    banners = await cms_repo.list_active_banners(db)
    featured = await cms_repo.list_featured(db, section="home_hot")
    newest = await film_repo.list_newest(db, limit=24)
    slides = newest[:8]

    sections: list[dict] = []
    for kind, slug, title, href in HOME_SECTIONS:
        films, total = await film_repo.list_films_page(
            db,
            page=1,
            page_size=16,
            genre=slug if kind == "genre" else None,
            country=slug if kind == "country" else None,
            film_type=slug if kind == "type" else None,
        )
        if len(films) < MIN_HOME_SECTION_ITEMS:
            continue
        sections.append(
            {
                "key": f"{kind}-{slug}",
                "title": title,
                "href": href,
                "total": total,
                "items": [serialize_film_card(f) for f in films],
            }
        )

    genres = await film_repo.list_genres(db)
    types = await film_repo.list_film_types(db)

    return {
        "success": True,
        "data": {
            "banners": [
                {
                    "id": b.id,
                    "title": b.title,
                    "imageUrl": b.image_url,
                    "linkUrl": b.link_url,
                    "filmSlug": b.film_slug,
                    "sortOrder": b.sort_order,
                }
                for b in banners
            ],
            "featured": [
                {
                    "id": f.id,
                    "section": f.section,
                    "sortOrder": f.sort_order,
                    "film": serialize_film_card(f.film, include_description=True),
                }
                for f in featured
                if f.film
            ],
            "slides": [serialize_film_card(f, include_description=True) for f in slides],
            "newest": [serialize_film_card(f) for f in newest],
            "topics": HOME_TOPICS,
            "sections": sections,
            "nav": {
                "genres": [{"slug": g.slug, "name": g.name} for g in genres[:12]],
                "types": [{"slug": t.slug, "name": t.name} for t in types],
                "countries": [
                    {"slug": c.slug, "name": c.name}
                    for c in await film_repo.list_countries(db)
                ][:12],
            },
        },
    }


async def get_detail(
    db: AsyncSession,
    *,
    slug: str,
    user_id: str | None = None,
) -> dict:
    settings = get_settings()
    now = time.monotonic()
    cached = _detail_cache.get(slug)
    episodes_payload: list[dict] = []
    detail_meta: dict | None = None

    if cached and now - cached[0] < settings.film_detail_cache_ttl_seconds:
        detail_meta = cached[1]
        episodes_payload = detail_meta.get("episodes") or []
    else:
        client = get_nguonc_client()
        try:
            detail = await client.fetch_detail(slug)
        except LookupError as exc:
            raise HTTPException(status_code=404, detail="Không tìm thấy phim") from exc
        except httpx.HTTPError as exc:
            raise HTTPException(status_code=502, detail="Không lấy được dữ liệu phim") from exc

        film = await film_repo.get_by_slug(db, slug=slug, with_taxonomy=True)
        if not film:
            film = Film(source_slug=detail.slug, name=detail.name or detail.slug)
            await film_repo.add_film(db, film)

        apply_detail_to_film(film, detail)
        film.synced_at = utcnow()
        genres, countries, types = split_taxonomy(detail.taxonomy)
        await film_repo.replace_film_taxonomy(
            db, film=film, genres=genres, countries=countries, types=types
        )
        await db.commit()

        episodes_payload = [
            {
                "serverName": s.server_name,
                "items": [
                    {"name": ep.name, "slug": ep.slug, "embed": ep.embed} for ep in s.items
                ],
            }
            for s in detail.episodes
        ]
        detail_meta = {"episodes": episodes_payload}
        _detail_cache[slug] = (now, detail_meta)

    film = await film_repo.get_by_slug(db, slug=slug, with_taxonomy=True)
    if not film or film.is_hidden:
        raise HTTPException(status_code=404, detail="Không tìm thấy phim")

    payload = serialize_film_card(film)
    payload.update(
        {
            "description": film.description,
            "time": film.time,
            "director": film.director,
            "casts": film.casts,
            "countries": [
                {"slug": fc.country.slug, "name": fc.country.name}
                for fc in (film.countries or [])
                if fc.country
            ],
            "types": [
                {"slug": ft.film_type.slug, "name": ft.film_type.name}
                for ft in (film.type_links or [])
                if ft.film_type
            ],
            "episodes": episodes_payload,
        }
    )

    if user_id:
        rating = await eng_repo.get_rating(db, user_id=user_id, film_id=film.id)
        watch = await eng_repo.get_watchlist_item(db, user_id=user_id, film_id=film.id)
        payload["userScore"] = rating.score if rating else None
        payload["inWatchlist"] = watch is not None

    return {"success": True, "data": payload}


async def admin_set_hidden(
    db: AsyncSession, *, actor_id: str, slug: str, is_hidden: bool
) -> dict:
    film = await film_repo.get_by_slug(db, slug=slug)
    if not film:
        raise HTTPException(status_code=404, detail="Không tìm thấy phim")
    await film_repo.set_hidden(db, film=film, is_hidden=is_hidden)
    await db.commit()
    await write_system_log(
        db,
        user_id=actor_id,
        action="UPDATE_FILM_VISIBILITY",
        resource="Film",
        details=f"{slug} hidden={is_hidden}",
    )
    return {"success": True, "data": serialize_film_card(film, include_hidden=True)}
