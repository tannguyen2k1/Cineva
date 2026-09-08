from __future__ import annotations

from io import BytesIO
from pathlib import Path

import httpx
import pytest
from PIL import Image

from app.core.config import get_settings
from app.models import Film, SyncRun
from app.services.film_images import (
    _convert_and_store,
    _is_public_ip,
    _validate_remote_url,
    source_fingerprint,
)
from app.services.film_mapper import serialize_film_card
from app.services.film_sync import serialize_sync_run
from app.services.nguonc_client import NguoncClient


def test_local_image_is_preferred_and_source_remains_fallback() -> None:
    film = Film(
        source_slug="test",
        name="Test",
        thumb_url="https://source.example/thumb.jpg",
        poster_url="https://source.example/poster.jpg",
        local_thumb_url="/uploads/films/1/thumb.webp",
    )
    card = serialize_film_card(film)
    assert card["thumbUrl"] == "/uploads/films/1/thumb.webp"
    assert card["posterUrl"] == "https://source.example/poster.jpg"


def test_sync_run_serializes_checkpoint_counters() -> None:
    run = SyncRun(
        job_type="full",
        checkpoint_page=12,
        total_pages=300,
        images_downloaded=22,
    )
    data = serialize_sync_run(run)
    assert data["checkpointPage"] == 12
    assert data["totalPages"] == 300
    assert data["imagesDownloaded"] == 22


def test_image_conversion_is_atomic_and_idempotent(tmp_path: Path) -> None:
    settings = get_settings()
    old_upload_dir = settings.upload_dir
    settings.upload_dir = str(tmp_path)
    try:
        source = BytesIO()
        Image.new("RGB", (20, 10), color="red").save(source, format="PNG")
        first = _convert_and_store(source.getvalue(), film_id="film-1", kind="poster")
        second = _convert_and_store(source.getvalue(), film_id="film-1", kind="poster")
        assert first == second
        target = tmp_path / first.removeprefix("/uploads/")
        assert target.exists()
        with Image.open(target) as image:
            assert image.format == "WEBP"
            assert image.size == (20, 10)
        assert not list(target.parent.glob("*.tmp"))
    finally:
        settings.upload_dir = old_upload_dir


def test_image_conversion_resizes_large_thumbnail(tmp_path: Path) -> None:
    settings = get_settings()
    old_upload_dir = settings.upload_dir
    settings.upload_dir = str(tmp_path)
    try:
        source = BytesIO()
        Image.new("RGB", (1200, 1800), color="blue").save(source, format="JPEG")
        local_url = _convert_and_store(
            source.getvalue(), film_id="film-2", kind="thumb"
        )
        target = tmp_path / local_url.removeprefix("/uploads/")
        with Image.open(target) as image:
            assert image.size == (600, 900)
    finally:
        settings.upload_dir = old_upload_dir


def test_ssrf_guards_and_fingerprint() -> None:
    assert _is_public_ip("1.1.1.1")
    assert not _is_public_ip("127.0.0.1")
    assert not _is_public_ip("10.0.0.1")
    assert source_fingerprint("https://example.com/a.jpg") == source_fingerprint(
        "https://example.com/a.jpg"
    )


@pytest.mark.asyncio
async def test_non_https_image_is_rejected() -> None:
    with pytest.raises(ValueError, match="public HTTPS"):
        await _validate_remote_url("http://127.0.0.1/image.jpg")


@pytest.mark.asyncio
async def test_nguonc_retries_server_errors() -> None:
    attempts = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal attempts
        attempts += 1
        if attempts == 1:
            return httpx.Response(503, request=request)
        return httpx.Response(200, json={"ok": True}, request=request)

    client = NguoncClient()
    await client._client.aclose()
    client._client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    client.request_delay = 0
    client.retry_base = 0.001
    try:
        assert await client._get("/api/films/phim-moi-cap-nhat/1") == {"ok": True}
        assert attempts == 2
    finally:
        await client.close()
