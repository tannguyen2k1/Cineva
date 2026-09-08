from __future__ import annotations

import asyncio
import hashlib
import ipaddress
import logging
import os
import socket
import tempfile
from io import BytesIO
from pathlib import Path
from urllib.parse import urljoin, urlparse
from datetime import timedelta

import httpx
from PIL import Image, UnidentifiedImageError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.timeutil import utcnow
from app.models import Film
from app.repositories import film as film_repo

logger = logging.getLogger(__name__)

IMAGE_PIPELINE_VERSION = "v2"
IMAGE_SIZES = {
    "thumb": (600, 900),
    "poster": (1600, 1000),
}
WEBP_QUALITY = 82


def source_fingerprint(url: str | None) -> str | None:
    return hashlib.sha256(url.encode()).hexdigest() if url else None


def _is_public_ip(value: str) -> bool:
    ip = ipaddress.ip_address(value)
    return not (
        ip.is_private
        or ip.is_loopback
        or ip.is_link_local
        or ip.is_multicast
        or ip.is_reserved
        or ip.is_unspecified
    )


async def _validate_remote_url(url: str) -> None:
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("Image URL must be public HTTPS")
    hostname = parsed.hostname.lower()
    loop = asyncio.get_running_loop()
    addresses = await loop.getaddrinfo(hostname, parsed.port or 443, type=socket.SOCK_STREAM)
    if not addresses or any(not _is_public_ip(row[4][0]) for row in addresses):
        raise ValueError("Image host resolves to a non-public address")


async def _download_image(client: httpx.AsyncClient, url: str) -> bytes:
    settings = get_settings()
    current = url
    for _ in range(6):
        await _validate_remote_url(current)
        async with client.stream("GET", current) as response:
            if response.is_redirect:
                location = response.headers.get("location")
                if not location:
                    raise ValueError("Image redirect has no location")
                current = urljoin(current, location)
                continue
            response.raise_for_status()
            content_type = response.headers.get("content-type", "").lower()
            if not content_type.startswith("image/"):
                raise ValueError(f"Unexpected image content type: {content_type}")
            declared = int(response.headers.get("content-length") or 0)
            if declared > settings.film_image_max_bytes:
                raise ValueError("Image exceeds byte limit")
            chunks: list[bytes] = []
            size = 0
            async for chunk in response.aiter_bytes():
                size += len(chunk)
                if size > settings.film_image_max_bytes:
                    raise ValueError("Image exceeds byte limit")
                chunks.append(chunk)
            return b"".join(chunks)
    raise ValueError("Too many image redirects")


def _convert_and_store(data: bytes, *, film_id: str, kind: str) -> str:
    settings = get_settings()
    try:
        with Image.open(BytesIO(data)) as image:
            image.verify()
        with Image.open(BytesIO(data)) as image:
            if image.width * image.height > settings.film_image_max_pixels:
                raise ValueError("Image exceeds pixel limit")
            image = image.convert("RGB")
            image.thumbnail(IMAGE_SIZES[kind], Image.Resampling.LANCZOS)
            target_dir = Path(settings.upload_dir) / "films" / film_id
            target_dir.mkdir(parents=True, exist_ok=True)
            digest = hashlib.sha256(
                data + f":{kind}:{IMAGE_PIPELINE_VERSION}".encode()
            ).hexdigest()[:20]
            target = target_dir / f"{kind}-{digest}.webp"
            if not target.exists():
                fd, temp_name = tempfile.mkstemp(
                    prefix=f".{kind}-", suffix=".tmp", dir=target_dir
                )
                try:
                    with os.fdopen(fd, "wb") as temp_file:
                        image.save(
                            temp_file,
                            format="WEBP",
                            quality=WEBP_QUALITY,
                            method=6,
                        )
                        temp_file.flush()
                        os.fsync(temp_file.fileno())
                    os.replace(temp_name, target)
                finally:
                    if os.path.exists(temp_name):
                        os.unlink(temp_name)
            return f"/uploads/films/{film_id}/{target.name}"
    except (Image.DecompressionBombError, UnidentifiedImageError, OSError) as exc:
        raise ValueError("Invalid or unsafe image") from exc


async def _mirror_one(
    client: httpx.AsyncClient, film: Film, *, kind: str, source_url: str
) -> bool:
    settings = get_settings()
    fingerprint = source_fingerprint(f"{IMAGE_PIPELINE_VERSION}:{source_url}")
    local_attr = f"local_{kind}_url"
    fingerprint_attr = f"{kind}_source_fingerprint"
    if getattr(film, local_attr) and getattr(film, fingerprint_attr) == fingerprint:
        return False

    last_error: Exception | None = None
    for attempt in range(max(1, settings.film_image_max_retries)):
        try:
            data = await _download_image(client, source_url)
            local_url = await asyncio.to_thread(
                _convert_and_store, data, film_id=film.id, kind=kind
            )
            setattr(film, local_attr, local_url)
            setattr(film, fingerprint_attr, fingerprint)
            return True
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            if attempt + 1 < settings.film_image_max_retries:
                await asyncio.sleep(0.5 * (2**attempt))
    assert last_error is not None
    raise last_error


async def mirror_film_images(films: list[Film]) -> tuple[int, int]:
    settings = get_settings()
    semaphore = asyncio.Semaphore(max(1, settings.film_image_concurrency))
    timeout = httpx.Timeout(settings.film_image_timeout_seconds)
    downloaded = 0
    failed = 0

    async with httpx.AsyncClient(
        timeout=timeout, follow_redirects=False, headers={"User-Agent": "CinevaImageMirror/1.0"}
    ) as client:
        async def mirror(film: Film) -> None:
            nonlocal downloaded, failed
            errors: list[str] = []
            image_count = 0
            async with semaphore:
                for kind, source_url in (("thumb", film.thumb_url), ("poster", film.poster_url)):
                    if not source_url:
                        continue
                    try:
                        image_count += int(
                            await _mirror_one(
                                client, film, kind=kind, source_url=source_url
                            )
                        )
                    except Exception as exc:  # noqa: BLE001
                        failed += 1
                        errors.append(f"{kind}: {exc}")
                        logger.warning("Image mirror failed for %s %s: %s", film.id, kind, exc)
            downloaded += image_count
            film.images_synced_at = utcnow()
            film.images_error = "; ".join(errors)[:2000] or None

        await asyncio.gather(*(mirror(film) for film in films))
    return downloaded, failed


async def cleanup_orphaned_images(db: AsyncSession, *, grace_days: int = 7) -> int:
    referenced = await film_repo.list_local_image_urls(db)
    settings = get_settings()
    root = Path(settings.upload_dir) / "films"
    if not root.exists():
        return 0
    cutoff = (utcnow() - timedelta(days=max(1, grace_days))).timestamp()
    removed = 0
    for path in root.rglob("*"):
        if not path.is_file() or path.stat().st_mtime >= cutoff:
            continue
        public_url = "/" + path.relative_to(Path(settings.upload_dir)).as_posix()
        if path.suffix == ".tmp" or public_url not in referenced:
            path.unlink(missing_ok=True)
            removed += 1
    return removed
