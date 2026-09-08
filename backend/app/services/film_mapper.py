from __future__ import annotations

from app.models import Film
from app.services.nguonc_client import NguoncFilmDetail, NguoncListItem, NguoncTaxonomyItem


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
            for fg in (film.genres or [])
            if fg.genre
        ],
    }
    if include_description:
        data["description"] = film.description
    if include_hidden:
        data["isHidden"] = film.is_hidden
    return data


def apply_list_item_to_film(film: Film, item: NguoncListItem) -> None:
    film.name = item.name or film.name
    film.original_name = item.original_name
    film.thumb_url = item.thumb_url
    film.poster_url = item.poster_url
    film.description = item.description
    film.total_episodes = item.total_episodes
    film.current_episode = item.current_episode
    film.time = item.time
    film.quality = item.quality
    film.language = item.language
    film.director = item.director
    film.casts = item.casts
    film.year = item.year
    film.source_modified_at = item.modified
    film.synced_at = film.synced_at  # set by caller


def apply_detail_to_film(film: Film, detail: NguoncFilmDetail) -> None:
    film.name = detail.name or film.name
    film.original_name = detail.original_name
    film.thumb_url = detail.thumb_url
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


def split_taxonomy(
    items: list[NguoncTaxonomyItem],
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
