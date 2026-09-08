"""HTTP client for public API."""

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


@dataclass
class NguoncListItem:
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


@dataclass
class NguoncEpisodeItem:
    name: str
    slug: str
    embed: str


@dataclass
class NguoncEpisodeServer:
    server_name: str
    items: list[NguoncEpisodeItem] = field(default_factory=list)


@dataclass
class NguoncTaxonomyItem:
    name: str
    slug: str
    group: str  # type | genre | year | country


@dataclass
class NguoncFilmDetail:
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
    taxonomy: list[NguoncTaxonomyItem] = field(default_factory=list)
    episodes: list[NguoncEpisodeServer] = field(default_factory=list)


@dataclass
class NguoncListPage:
    current_page: int
    total_page: int
    total_items: int
    items_per_page: int
    items: list[NguoncListItem]


def _parse_dt(value: Any) -> datetime | None:
    if not value or not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _map_list_item(raw: dict[str, Any]) -> NguoncListItem:
    return NguoncListItem(
        name=raw.get("name") or "",
        slug=raw.get("slug") or "",
        original_name=raw.get("original_name"),
        thumb_url=raw.get("thumb_url"),
        poster_url=raw.get("poster_url"),
        description=raw.get("description"),
        total_episodes=raw.get("total_episodes"),
        current_episode=raw.get("current_episode"),
        time=raw.get("time"),
        quality=raw.get("quality"),
        language=raw.get("language"),
        director=raw.get("director"),
        casts=raw.get("casts"),
        year=str(raw["year"]) if raw.get("year") is not None else None,
        created=_parse_dt(raw.get("created")),
        modified=_parse_dt(raw.get("modified")),
    )


def _map_taxonomy(category: Any) -> list[NguoncTaxonomyItem]:
    result: list[NguoncTaxonomyItem] = []
    if not isinstance(category, dict):
        return result
    for entry in category.values():
        if not isinstance(entry, dict):
            continue
        group = (entry.get("group") or {}).get("name") or ""
        group_key = "genre"
        g_lower = group.lower()
        if "định" in g_lower or "dinh" in g_lower or "format" in g_lower:
            group_key = "type"
        elif "năm" in g_lower or "nam" in g_lower or "year" in g_lower:
            group_key = "year"
        elif "quốc" in g_lower or "quoc" in g_lower or "country" in g_lower:
            group_key = "country"
        elif "thể" in g_lower or "the" in g_lower or "genre" in g_lower:
            group_key = "genre"
        for item in entry.get("list") or []:
            if not isinstance(item, dict):
                continue
            name = item.get("name") or ""
            if not name:
                continue
            result.append(
                NguoncTaxonomyItem(name=name, slug=slugify(name) or "unknown", group=group_key)
            )
    return result


def _map_detail(raw: dict[str, Any]) -> NguoncFilmDetail:
    movie = raw.get("movie") or {}
    episodes: list[NguoncEpisodeServer] = []
    for server in movie.get("episodes") or []:
        if not isinstance(server, dict):
            continue
        items = [
            NguoncEpisodeItem(
                name=str(ep.get("name") or ""),
                slug=str(ep.get("slug") or ""),
                embed=str(ep.get("embed") or ""),
            )
            for ep in (server.get("items") or [])
            if isinstance(ep, dict)
        ]
        episodes.append(
            NguoncEpisodeServer(
                server_name=str(server.get("server_name") or "Server"),
                items=items,
            )
        )

    year = None
    taxonomy = _map_taxonomy(movie.get("category"))
    for t in taxonomy:
        if t.group == "year":
            year = t.name
            break

    return NguoncFilmDetail(
        id=movie.get("id"),
        name=movie.get("name") or "",
        slug=movie.get("slug") or "",
        original_name=movie.get("original_name"),
        thumb_url=movie.get("thumb_url"),
        poster_url=movie.get("poster_url"),
        description=movie.get("description"),
        total_episodes=movie.get("total_episodes"),
        current_episode=movie.get("current_episode"),
        time=movie.get("time"),
        quality=movie.get("quality"),
        language=movie.get("language"),
        director=movie.get("director"),
        casts=movie.get("casts"),
        year=year or (str(movie["year"]) if movie.get("year") is not None else None),
        created=_parse_dt(movie.get("created")),
        modified=_parse_dt(movie.get("modified")),
        taxonomy=taxonomy,
        episodes=episodes,
    )


class NguoncClient:
    def __init__(self) -> None:
        settings = get_settings()
        self.base_url = settings.nguonc_base_url.rstrip("/")
        self.timeout = settings.nguonc_timeout_seconds
        self.max_retries = max(1, settings.nguonc_max_retries)
        self.retry_base = max(0.1, settings.nguonc_retry_base_seconds)
        self.request_delay = max(0.0, settings.nguonc_request_delay_seconds)
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
                    raise ValueError("Invalid nguonc response")
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
                    "Nguonc request failed (%s), retry %s/%s in %.2fs",
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

    def _map_list_page(self, data: dict[str, Any]) -> NguoncListPage:
        paginate = data.get("paginate") or {}
        items = [
            _map_list_item(item)
            for item in (data.get("items") or [])
            if isinstance(item, dict) and item.get("slug")
        ]
        return NguoncListPage(
            current_page=int(paginate.get("current_page") or 1),
            total_page=int(paginate.get("total_page") or 1),
            total_items=int(paginate.get("total_items") or len(items)),
            items_per_page=int(paginate.get("items_per_page") or 10),
            items=items,
        )

    async def fetch_newest(self, page: int = 1) -> NguoncListPage:
        data = await self._get("/api/films/phim-moi-cap-nhat", {"page": page})
        return self._map_list_page(data)

    async def fetch_by_list(self, slug: str, page: int = 1) -> NguoncListPage:
        data = await self._get(f"/api/films/danh-sach/{slug}", {"page": page})
        return self._map_list_page(data)

    async def fetch_by_genre(self, slug: str, page: int = 1) -> NguoncListPage:
        data = await self._get(f"/api/films/the-loai/{slug}", {"page": page})
        return self._map_list_page(data)

    async def fetch_by_country(self, slug: str, page: int = 1) -> NguoncListPage:
        data = await self._get(f"/api/films/quoc-gia/{slug}", {"page": page})
        return self._map_list_page(data)

    async def fetch_by_year(self, year: str, page: int = 1) -> NguoncListPage:
        data = await self._get(f"/api/films/nam-phat-hanh/{year}", {"page": page})
        return self._map_list_page(data)

    async def search(self, keyword: str, page: int = 1) -> NguoncListPage:
        data = await self._get(
            "/api/films/search", {"keyword": keyword, "page": page}
        )
        return self._map_list_page(data)

    async def fetch_detail(self, slug: str) -> NguoncFilmDetail:
        data = await self._get(f"/api/film/{slug}")
        if data.get("status") != "success":
            raise LookupError(f"Film not found: {slug}")
        detail = _map_detail(data)
        if not detail.slug:
            raise LookupError(f"Film not found: {slug}")
        return detail


_client: NguoncClient | None = None


def get_nguonc_client() -> NguoncClient:
    global _client
    if _client is None:
        _client = NguoncClient()
    return _client
