from __future__ import annotations

from datetime import datetime

from slugify import slugify
from sqlalchemy import Select, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import (
    Country,
    Film,
    FilmCountry,
    FilmGenre,
    FilmType,
    FilmTypeLink,
    Genre,
)


def film_with_taxonomy_options():
    return (
        selectinload(Film.genres).selectinload(FilmGenre.genre),
        selectinload(Film.countries).selectinload(FilmCountry.country),
        selectinload(Film.type_links).selectinload(FilmTypeLink.film_type),
    )


async def get_by_slug(
    db: AsyncSession, *, slug: str, with_taxonomy: bool = False
) -> Film | None:
    stmt = select(Film).where(Film.source_slug == slug)
    if with_taxonomy:
        stmt = stmt.options(*film_with_taxonomy_options())
    return (await db.execute(stmt)).scalar_one_or_none()


async def get_by_id(
    db: AsyncSession, *, film_id: str, with_taxonomy: bool = False
) -> Film | None:
    stmt = select(Film).where(Film.id == film_id)
    if with_taxonomy:
        stmt = stmt.options(*film_with_taxonomy_options())
    return (await db.execute(stmt)).scalar_one_or_none()


def _apply_filters(
    stmt: Select,
    *,
    q: str | None = None,
    genre: str | None = None,
    country: str | None = None,
    year: str | None = None,
    film_type: str | None = None,
    include_hidden: bool = False,
) -> Select:
    if not include_hidden:
        stmt = stmt.where(Film.is_hidden.is_(False))
    if q:
        raw = q.strip()
        like = f"%{raw}%"
        # Accent-insensitive fallback via slug (e.g. "pham nhan" → pham-nhan-…)
        slug_token = slugify(raw)
        clauses = [Film.name.ilike(like), Film.original_name.ilike(like)]
        if slug_token:
            clauses.append(Film.source_slug.ilike(f"%{slug_token}%"))
        stmt = stmt.where(or_(*clauses))
    if year:
        stmt = stmt.where(Film.year == year)
    if genre:
        stmt = (
            stmt.join(FilmGenre, FilmGenre.film_id == Film.id)
            .join(Genre, Genre.id == FilmGenre.genre_id)
            .where(Genre.slug == genre)
        )
    if country:
        stmt = (
            stmt.join(FilmCountry, FilmCountry.film_id == Film.id)
            .join(Country, Country.id == FilmCountry.country_id)
            .where(Country.slug == country)
        )
    if film_type:
        stmt = (
            stmt.join(FilmTypeLink, FilmTypeLink.film_id == Film.id)
            .join(FilmType, FilmType.id == FilmTypeLink.film_type_id)
            .where(FilmType.slug == film_type)
        )
    return stmt


async def list_films_page(
    db: AsyncSession,
    *,
    page: int,
    page_size: int,
    q: str | None = None,
    genre: str | None = None,
    country: str | None = None,
    year: str | None = None,
    film_type: str | None = None,
    include_hidden: bool = False,
    sort: str = "newest",
) -> tuple[list[Film], int]:
    base = select(Film)
    base = _apply_filters(
        base,
        q=q,
        genre=genre,
        country=country,
        year=year,
        film_type=film_type,
        include_hidden=include_hidden,
    ).distinct()

    count_stmt = select(func.count()).select_from(base.subquery())
    total = (await db.execute(count_stmt)).scalar_one()

    if sort == "name":
        order = (Film.name.asc(), Film.id.asc())
    elif sort == "year":
        order = (Film.year.desc().nullslast(), Film.source_modified_at.desc().nullslast())
    else:
        # newest (default)
        order = (
            Film.source_modified_at.desc().nullslast(),
            Film.synced_at.desc().nullslast(),
        )

    result = await db.execute(
        base.options(*film_with_taxonomy_options())
        .order_by(*order)
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return list(result.scalars().unique().all()), total


async def list_newest(db: AsyncSession, *, limit: int = 20) -> list[Film]:
    result = await db.execute(
        select(Film)
        .where(Film.is_hidden.is_(False))
        .options(*film_with_taxonomy_options())
        .order_by(Film.source_modified_at.desc().nullslast(), Film.synced_at.desc().nullslast())
        .limit(limit)
    )
    return list(result.scalars().unique().all())


async def add_film(db: AsyncSession, film: Film) -> Film:
    db.add(film)
    await db.flush()
    return film


async def set_hidden(db: AsyncSession, *, film: Film, is_hidden: bool) -> Film:
    film.is_hidden = is_hidden
    await db.flush()
    return film


async def update_rating_aggregate(
    db: AsyncSession, *, film_id: str, avg: float, count: int
) -> None:
    await db.execute(
        update(Film)
        .where(Film.id == film_id)
        .values(avg_rating=avg, rating_count=count)
    )


async def get_or_create_genre(db: AsyncSession, *, slug: str, name: str) -> Genre:
    existing = (
        await db.execute(select(Genre).where(Genre.slug == slug))
    ).scalar_one_or_none()
    if existing:
        if existing.name != name:
            existing.name = name
        return existing
    genre = Genre(slug=slug, name=name)
    db.add(genre)
    await db.flush()
    return genre


async def get_or_create_country(db: AsyncSession, *, slug: str, name: str) -> Country:
    existing = (
        await db.execute(select(Country).where(Country.slug == slug))
    ).scalar_one_or_none()
    if existing:
        if existing.name != name:
            existing.name = name
        return existing
    country = Country(slug=slug, name=name)
    db.add(country)
    await db.flush()
    return country


async def get_or_create_film_type(db: AsyncSession, *, slug: str, name: str) -> FilmType:
    existing = (
        await db.execute(select(FilmType).where(FilmType.slug == slug))
    ).scalar_one_or_none()
    if existing:
        if existing.name != name:
            existing.name = name
        return existing
    ft = FilmType(slug=slug, name=name)
    db.add(ft)
    await db.flush()
    return ft


async def replace_film_taxonomy(
    db: AsyncSession,
    *,
    film: Film,
    genres: list[tuple[str, str]],
    countries: list[tuple[str, str]],
    types: list[tuple[str, str]],
) -> None:
    film.genres.clear()
    film.countries.clear()
    film.type_links.clear()
    await db.flush()

    for slug, name in genres:
        g = await get_or_create_genre(db, slug=slug, name=name)
        film.genres.append(FilmGenre(genre_id=g.id))
    for slug, name in countries:
        c = await get_or_create_country(db, slug=slug, name=name)
        film.countries.append(FilmCountry(country_id=c.id))
    for slug, name in types:
        t = await get_or_create_film_type(db, slug=slug, name=name)
        film.type_links.append(FilmTypeLink(film_type_id=t.id))
    await db.flush()


async def ensure_film_genre(db: AsyncSession, *, film: Film, slug: str, name: str) -> None:
    genre = await get_or_create_genre(db, slug=slug, name=name)
    existing = (
        await db.execute(
            select(FilmGenre).where(
                FilmGenre.film_id == film.id, FilmGenre.genre_id == genre.id
            )
        )
    ).scalar_one_or_none()
    if existing:
        return
    db.add(FilmGenre(film_id=film.id, genre_id=genre.id))
    await db.flush()


async def ensure_film_country(
    db: AsyncSession, *, film: Film, slug: str, name: str
) -> None:
    country = await get_or_create_country(db, slug=slug, name=name)
    existing = (
        await db.execute(
            select(FilmCountry).where(
                FilmCountry.film_id == film.id, FilmCountry.country_id == country.id
            )
        )
    ).scalar_one_or_none()
    if existing:
        return
    db.add(FilmCountry(film_id=film.id, country_id=country.id))
    await db.flush()


async def ensure_film_type(db: AsyncSession, *, film: Film, slug: str, name: str) -> None:
    film_type = await get_or_create_film_type(db, slug=slug, name=name)
    existing = (
        await db.execute(
            select(FilmTypeLink).where(
                FilmTypeLink.film_id == film.id,
                FilmTypeLink.film_type_id == film_type.id,
            )
        )
    ).scalar_one_or_none()
    if existing:
        return
    db.add(FilmTypeLink(film_id=film.id, film_type_id=film_type.id))
    await db.flush()


async def list_genres(db: AsyncSession) -> list[Genre]:
    return list((await db.execute(select(Genre).order_by(Genre.name))).scalars().all())


async def list_countries(db: AsyncSession) -> list[Country]:
    return list((await db.execute(select(Country).order_by(Country.name))).scalars().all())


async def list_film_types(db: AsyncSession) -> list[FilmType]:
    return list((await db.execute(select(FilmType).order_by(FilmType.name))).scalars().all())


async def list_years(db: AsyncSession) -> list[str]:
    result = await db.execute(
        select(Film.year)
        .where(Film.year.is_not(None), Film.is_hidden.is_(False))
        .distinct()
        .order_by(Film.year.desc())
    )
    return [y for y in result.scalars().all() if y]


async def count_films(db: AsyncSession, *, include_hidden: bool = True) -> int:
    stmt = select(func.count()).select_from(Film)
    if not include_hidden:
        stmt = stmt.where(Film.is_hidden.is_(False))
    return (await db.execute(stmt)).scalar_one()


async def count_hidden_films(db: AsyncSession) -> int:
    return (
        await db.execute(
            select(func.count()).select_from(Film).where(Film.is_hidden.is_(True))
        )
    ).scalar_one()


async def list_sitemap_films(
    db: AsyncSession, *, limit: int = 5000
) -> list[tuple[str, datetime]]:
    result = await db.execute(
        select(Film.source_slug, Film.updated_at)
        .where(Film.is_hidden.is_(False))
        .order_by(Film.updated_at.desc())
        .limit(limit)
    )
    return [(slug, updated_at) for slug, updated_at in result.all()]


async def latest_source_modified(db: AsyncSession) -> datetime | None:
    return (
        await db.execute(select(func.max(Film.source_modified_at)))
    ).scalar_one_or_none()
