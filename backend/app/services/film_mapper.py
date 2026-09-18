from __future__ import annotations

from sqlalchemy import inspect as sa_inspect

from app.models import Film
from app.services.kkphim_client import (
    CatalogFilmDetail,
    CatalogListItem,
    CatalogTaxonomyItem,
)


def _relation_or_empty(film: Film, name: str):
    """Return a loaded relationship collection, or [] — never lazy-load in async."""
    state = sa_inspect(film)
    if name in state.unloaded:
        return []
    return getattr(film, name) or []


def serialize_film_card(film: Film, *, include_hidden: bool = False, include_description: bool = False) -> dict:
    data = {
        "id": film.id,
        "slug": film.source_slug,
        "name": film.name,
        "originalName": film.original_name,
        "thumbUrl": film.local_thumb_url or film.thumb_url,
        "posterUrl": film.local_poster_url or film.poster_url,
        "year": film.year,
        "quality": film.quality,
        "language": film.language,
        "currentEpisode": film.current_episode,
        "totalEpisodes": film.total_episodes,
        "avgRating": round(film.avg_rating or 0, 1),
        "ratingCount": film.rating_count or 0,
        "genres": [
            {"slug": fg.genre.slug, "name": fg.genre.name}
            for fg in _relation_or_empty(film, "genres")
            if fg.genre
        ],
    }
    if include_description:
        data["description"] = film.description
    if include_hidden:
        data["isHidden"] = film.is_hidden
    return data


def _apply_scores(film: Film, *, avg_rating: float | None, rating_count: int | None) -> None:
    if avg_rating is None:
        return
    film.avg_rating = float(avg_rating)
    film.rating_count = int(rating_count or 0)


def apply_list_item_to_film(film: Film, item: CatalogListItem) -> None:
    film.name = item.name or film.name
    if item.original_name is not None:
        film.original_name = item.original_name
    if item.thumb_url:
        film.thumb_url = item.thumb_url
    if item.poster_url:
        film.poster_url = item.poster_url
    if item.description:
        film.description = item.description
    if item.total_episodes is not None:
        film.total_episodes = item.total_episodes
    if item.current_episode is not None:
        film.current_episode = item.current_episode
    if item.time is not None:
        film.time = item.time
    if item.quality is not None:
        film.quality = item.quality
    if item.language is not None:
        film.language = item.language
    if item.director is not None:
        film.director = item.director
    if item.casts is not None:
        film.casts = item.casts
    if item.year is not None:
        film.year = item.year
    if item.modified is not None:
        film.source_modified_at = item.modified
    _apply_scores(film, avg_rating=item.avg_rating, rating_count=item.rating_count)


def apply_detail_to_film(film: Film, detail: CatalogFilmDetail) -> None:
    film.name = detail.name or film.name
    film.original_name = detail.original_name
    if detail.thumb_url:
        film.thumb_url = detail.thumb_url
    if detail.poster_url:
        film.poster_url = detail.poster_url
    film.description = detail.description
    film.total_episodes = detail.total_episodes
    film.current_episode = detail.current_episode
    film.time = detail.time
    film.quality = detail.quality
    film.language = detail.language
    film.director = detail.director
    film.casts = detail.casts
    film.year = detail.year
    film.source_modified_at = detail.modified
    _apply_scores(film, avg_rating=detail.avg_rating, rating_count=detail.rating_count)


def split_taxonomy(
    items: list[CatalogTaxonomyItem],
) -> tuple[list[tuple[str, str]], list[tuple[str, str]], list[tuple[str, str]]]:
    genres: list[tuple[str, str]] = []
    countries: list[tuple[str, str]] = []
    types: list[tuple[str, str]] = []
    for t in items:
        pair = (t.slug, t.name)
        if t.group == "country":
            countries.append(pair)
        elif t.group == "type":
            types.append(pair)
        elif t.group == "year":
            continue
        else:
            genres.append(pair)
    return genres, countries, types
