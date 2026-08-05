"""In-memory sliding-window rate limiter (per-process).

Fine for single Uvicorn worker / template defaults. Multi-instance prod
should put Redis (or nginx/gateway) in front — see settings notes.
"""

from __future__ import annotations

import threading
import time
from collections import defaultdict, deque


class SlidingWindowLimiter:
    def __init__(self) -> None:
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()
        self._last_cleanup = time.monotonic()

    def check(self, key: str, *, limit: int, window_seconds: float) -> tuple[bool, int]:
        """Return (allowed, retry_after_seconds)."""
        if limit <= 0:
            return True, 0

        now = time.monotonic()
        with self._lock:
            self._maybe_cleanup(now)
            bucket = self._hits[key]
            cutoff = now - window_seconds
            while bucket and bucket[0] <= cutoff:
                bucket.popleft()

            if len(bucket) >= limit:
                retry = int(bucket[0] + window_seconds - now) + 1
                return False, max(retry, 1)

            bucket.append(now)
            return True, 0

    def _maybe_cleanup(self, now: float) -> None:
        # Drop idle keys occasionally to avoid unbounded growth
        if now - self._last_cleanup < 60:
            return
        self._last_cleanup = now
        stale = [k for k, q in self._hits.items() if not q or q[-1] < now - 3600]
        for k in stale:
            del self._hits[k]


limiter = SlidingWindowLimiter()
