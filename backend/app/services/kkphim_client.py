"""HTTP client for KKPhim / phimapi.com catalog API."""

from __future__ import annotations

import asyncio
import logging
import random
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

import httpx
from slugify import slugify

from app.core.config import get_settings

logger = logging.getLogger(__name__)

DEFAULT_CDN = "https://phimimg.com"

TYPE_SLUG_MAP: dict[str, tuple[str, str]] = {
    "single": ("phim-le", "Phim Lẻ"),
    "series": ("phim-bo", "Phim Bộ"),
    "hoathinh": ("hoat-hinh", "Hoạt Hình"),
    "tvshows": ("tv-shows", "TV Shows"),
}


@dataclass
class CatalogListItem:
    name: str
    slug: str
    original_name: str | None = None
    thumb_url: str | None = None
    poster_url: str | None = None
    description: str | None = None
    total_episodes: int | None = None
    current_episode: str | None = None
    time: str | None = None
    quality: str | None = None
    language: str | None = None
    director: str | None = None
    casts: str | None = None
    year: str | None = None
    created: datetime | None = None
    modified: datetime | None = None
    avg_rating: float | None = None
    rating_count: int | None = None
    film_type_slug: str | None = None
    film_type_name: str | None = None


@dataclass
class CatalogEpisodeItem:
    name: str
    slug: str
    embed: str


@dataclass
class CatalogEpisodeServer:
    server_name: str
    items: list[CatalogEpisodeItem] = field(default_factory=list)


@dataclass
class CatalogTaxonomyItem:
    name: str
    slug: str
    group: str  # type | genre | year | country


@dataclass
class CatalogFilmDetail:
    id: str | None
    name: str
    slug: str
    original_name: str | None
    thumb_url: str | None
    poster_url: str | None
    description: str | None
    total_episodes: int | None
    current_episode: str | None
    time: str | None
    quality: str | None
    language: str | None
    director: str | None
    casts: str | None
    year: str | None
    created: datetime | None
    modified: datetime | None
    avg_rating: float | None = None
    rating_count: int | None = None
    taxonomy: list[CatalogTaxonomyItem] = field(default_factory=list)
    episodes: list[CatalogEpisodeServer] = field(default_factory=list)


@dataclass
class CatalogListPage:
    current_page: int
    total_page: int
    total_items: int
    items_per_page: int
    items: list[CatalogListItem]


def _parse_dt(value: Any) -> datetime | None:
    if isinstance(value, dict):
        value = value.get("time")
    if not value or not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _abs_image(url: str | None, cdn: str = DEFAULT_CDN) -> str | None:
    if not url or not isinstance(url, str):
        return None
    text = url.strip()
    if not text:
        return None
    if text.startswith("http://") or text.startswith("https://"):
        return text
    return f"{cdn.rstrip('/')}/{text.lstrip('/')}"


def _join_people(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, list):
        parts = [str(x).strip() for x in value if str(x).strip()]
        return ", ".join(parts) if parts else None
    text = str(value).strip()
    return text or None


def _parse_int(value: Any) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return None


def _pick_scores(raw: dict[str, Any]) -> tuple[float | None, int | None]:
    imdb = raw.get("imdb") if isinstance(raw.get("imdb"), dict) else {}
    tmdb = raw.get("tmdb") if isinstance(raw.get("tmdb"), dict) else {}

    def _score(block: dict[str, Any]) -> tuple[float | None, int | None]:
        try:
            avg = float(block.get("vote_average") or 0)
        except (TypeError, ValueError):
            avg = 0.0
        try:
            count = int(block.get("vote_count") or 0)
        except (TypeError, ValueError):
            count = 0
        if avg > 0:
            return round(avg, 1), max(0, count)
        return None, None

    imdb_score = _score(imdb)
    if imdb_score[0] is not None:
        return imdb_score
    return _score(tmdb)


def _type_from_raw(raw: dict[str, Any]) -> tuple[str | None, str | None]:
    key = str(raw.get("type") or "").strip().lower()
    if key in TYPE_SLUG_MAP:
        return TYPE_SLUG_MAP[key]
    return None, None


def _map_list_item(raw: dict[str, Any], *, cdn: str = DEFAULT_CDN) -> CatalogListItem:
    avg, count = _pick_scores(raw)
    type_slug, type_name = _type_from_raw(raw)
    return CatalogListItem(
        name=raw.get("name") or "",
        slug=raw.get("slug") or "",
        original_name=raw.get("origin_name") or raw.get("original_name"),
        thumb_url=_abs_image(raw.get("thumb_url"), cdn),
        poster_url=_abs_image(raw.get("poster_url"), cdn),
        description=raw.get("content") or raw.get("description"),
        total_episodes=_parse_int(raw.get("episode_total") or raw.get("total_episodes")),
        current_episode=(
            str(raw["episode_current"])
            if raw.get("episode_current") is not None
            else (str(raw["current_episode"]) if raw.get("current_episode") is not None else None)
        ),
        time=raw.get("time"),
        quality=raw.get("quality"),
        language=raw.get("lang") or raw.get("language"),
        director=_join_people(raw.get("director")),
        casts=_join_people(raw.get("actor") or raw.get("casts")),
        year=str(raw["year"]) if raw.get("year") is not None else None,
        created=_parse_dt(raw.get("created")),
        modified=_parse_dt(raw.get("modified")),
        avg_rating=avg,
        rating_count=count,
        film_type_slug=type_slug,
        film_type_name=type_name,
    )


def _map_taxonomy_from_detail(movie: dict[str, Any]) -> list[CatalogTaxonomyItem]:
    result: list[CatalogTaxonomyItem] = []
    for item in movie.get("category") or []:
        if not isinstance(item, dict):
            continue
        name = (item.get("name") or "").strip()
        if not name:
            continue
        result.append(
            CatalogTaxonomyItem(
                name=name,
                slug=(item.get("slug") or slugify(name) or "unknown"),
                group="genre",
            )
        )
    for item in movie.get("country") or []:
        if not isinstance(item, dict):
            continue
        name = (item.get("name") or "").strip()
        if not name:
            continue
        result.append(
            CatalogTaxonomyItem(
                name=name,
                slug=(item.get("slug") or slugify(name) or "unknown"),
                group="country",
            )
        )
    type_slug, type_name = _type_from_raw(movie)
    if type_slug and type_name:
        result.append(CatalogTaxonomyItem(name=type_name, slug=type_slug, group="type"))
    if movie.get("year") is not None:
        year = str(movie["year"])
        result.append(CatalogTaxonomyItem(name=year, slug=year, group="year"))
    return result


def _map_episodes(raw_episodes: Any) -> list[CatalogEpisodeServer]:
    episodes: list[CatalogEpisodeServer] = []
    if not isinstance(raw_episodes, list):
        return episodes
    for server in raw_episodes:
        if not isinstance(server, dict):
            continue
        items: list[CatalogEpisodeItem] = []
        for ep in server.get("server_data") or server.get("items") or []:
            if not isinstance(ep, dict):
                continue
            embed = str(ep.get("link_embed") or ep.get("embed") or "").strip()
            if not embed:
                m3u8 = str(ep.get("link_m3u8") or "").strip()
                if m3u8:
                    embed = f"https://player.phimapi.com/player/?url={m3u8}"
            items.append(
                CatalogEpisodeItem(
                    name=str(ep.get("name") or ""),
                    slug=str(ep.get("slug") or ""),
                    embed=embed,
                )
            )
        if items:
            episodes.append(
                CatalogEpisodeServer(
                    server_name=str(server.get("server_name") or "Server"),
                    items=items,
                )
            )
    return episodes


def _map_detail(raw: dict[str, Any]) -> CatalogFilmDetail:
    movie = raw.get("movie") or {}
    if not isinstance(movie, dict):
        movie = {}
    avg, count = _pick_scores(movie)
    taxonomy = _map_taxonomy_from_detail(movie)
    year = str(movie["year"]) if movie.get("year") is not None else None
    return CatalogFilmDetail(
        id=movie.get("_id") or movie.get("id"),
        name=movie.get("name") or "",
        slug=movie.get("slug") or "",
        original_name=movie.get("origin_name") or movie.get("original_name"),
        thumb_url=_abs_image(movie.get("thumb_url")),
        poster_url=_abs_image(movie.get("poster_url")),
        description=movie.get("content") or movie.get("description"),
        total_episodes=_parse_int(movie.get("episode_total") or movie.get("total_episodes")),
        current_episode=(
            str(movie["episode_current"])
            if movie.get("episode_current") is not None
            else None
        ),
        time=movie.get("time"),
        quality=movie.get("quality"),
        language=movie.get("lang") or movie.get("language"),
        director=_join_people(movie.get("director")),
        casts=_join_people(movie.get("actor") or movie.get("casts")),
        year=year,
        created=_parse_dt(movie.get("created")),
        modified=_parse_dt(movie.get("modified")),
        avg_rating=avg,
        rating_count=count,
        taxonomy=taxonomy,
        episodes=_map_episodes(raw.get("episodes") or movie.get("episodes")),
    )


def _truthy_status(data: dict[str, Any]) -> bool:
    status = data.get("status")
    if status is True:
        return True
    if isinstance(status, str) and status.lower() in {"success", "true", "ok", "done"}:
        return True
    return False


class KkphimClient:
    def __init__(self) -> None:
        settings = get_settings()
        self.base_url = settings.kkphim_base_url.rstrip("/")
        self.timeout = settings.kkphim_timeout_seconds
        self.max_retries = max(1, settings.kkphim_max_retries)
        self.retry_base = max(0.1, settings.kkphim_retry_base_seconds)
        self.request_delay = max(0.0, settings.kkphim_request_delay_seconds)
        self._client = httpx.AsyncClient(
            timeout=httpx.Timeout(self.timeout),
            follow_redirects=True,
            headers={"User-Agent": "CinevaCatalogSync/1.0"},
        )

    async def _get(self, path: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        url = f"{self.base_url}{path}"
        last_error: Exception | None = None
        for attempt in range(self.max_retries):
            try:
                if self.request_delay:
                    await asyncio.sleep(self.request_delay)
                resp = await self._client.get(url, params=params)
                resp.raise_for_status()
                data = resp.json()
                if not isinstance(data, dict):
                    raise ValueError("Invalid kkphim response")
                return data
            except (httpx.TimeoutException, httpx.NetworkError, httpx.HTTPStatusError) as exc:
                last_error = exc
                retryable = not isinstance(exc, httpx.HTTPStatusError) or (
                    exc.response.status_code == 429 or exc.response.status_code >= 500
                )
                if not retryable or attempt + 1 >= self.max_retries:
                    raise
                delay = self.retry_base * (2**attempt) + random.uniform(0, 0.25)
                logger.warning(
                    "KKPhim request failed (%s), retry %s/%s in %.2fs",
                    exc,
                    attempt + 1,
                    self.max_retries,
                    delay,
                )
                await asyncio.sleep(delay)
        assert last_error is not None
        raise last_error

    async def close(self) -> None:
        await self._client.aclose()

    def _map_list_page(self, data: dict[str, Any]) -> CatalogListPage:
        # Newest endpoint: top-level items + pagination
        # v1 endpoints: data.items + data.params.pagination + CDN domain
        block = data.get("data") if isinstance(data.get("data"), dict) else None
        items_raw = (block or data).get("items") or data.get("items") or []
        paginate = {}
        if block and isinstance(block.get("params"), dict):
            paginate = block["params"].get("pagination") or {}
        if not paginate:
            paginate = data.get("pagination") or data.get("paginate") or {}

        cdn = DEFAULT_CDN
        if block and block.get("APP_DOMAIN_CDN_IMAGE"):
            cdn = str(block["APP_DOMAIN_CDN_IMAGE"]).rstrip("/")

        items = [
            _map_list_item(item, cdn=cdn)
            for item in items_raw
            if isinstance(item, dict) and item.get("slug")
        ]
        return CatalogListPage(
            current_page=int(
                paginate.get("currentPage")
                or paginate.get("current_page")
                or 1
            ),
            total_page=int(
                paginate.get("totalPages")
                or paginate.get("total_page")
                or 1
            ),
            total_items=int(
                paginate.get("totalItems")
                or paginate.get("total_items")
                or len(items)
            ),
            items_per_page=int(
                paginate.get("totalItemsPerPage")
                or paginate.get("items_per_page")
                or len(items)
                or 24
            ),
            items=items,
        )

    async def fetch_newest(self, page: int = 1) -> CatalogListPage:
        data = await self._get("/danh-sach/phim-moi-cap-nhat", {"page": page})
        return self._map_list_page(data)

    async def fetch_by_list(self, slug: str, page: int = 1) -> CatalogListPage:
        data = await self._get(f"/v1/api/danh-sach/{slug}", {"page": page})
        return self._map_list_page(data)

    async def fetch_by_genre(self, slug: str, page: int = 1) -> CatalogListPage:
        data = await self._get(f"/v1/api/the-loai/{slug}", {"page": page})
        return self._map_list_page(data)

    async def fetch_by_country(self, slug: str, page: int = 1) -> CatalogListPage:
        data = await self._get(f"/v1/api/quoc-gia/{slug}", {"page": page})
        return self._map_list_page(data)

    async def fetch_by_year(self, year: str, page: int = 1) -> CatalogListPage:
        data = await self._get(f"/v1/api/nam/{year}", {"page": page})
        return self._map_list_page(data)

    async def search(self, keyword: str, page: int = 1) -> CatalogListPage:
        data = await self._get("/v1/api/tim-kiem", {"keyword": keyword, "page": page})
        return self._map_list_page(data)

    async def fetch_detail(self, slug: str) -> CatalogFilmDetail:
        data = await self._get(f"/phim/{slug}")
        if not _truthy_status(data):
            raise LookupError(f"Film not found: {slug}")
        detail = _map_detail(data)
        if not detail.slug:
            raise LookupError(f"Film not found: {slug}")
        return detail


_client: KkphimClient | None = None


def get_kkphim_client() -> KkphimClient:
    global _client
    if _client is None:
        _client = KkphimClient()
    return _client
