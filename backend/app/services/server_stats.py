from __future__ import annotations

import os
import platform
from pathlib import Path

import psutil

from app.core.timeutil import to_iso_utc

# Non-blocking cpu_percent needs a prior call to have a baseline.
psutil.cpu_percent(interval=None)


def get_server_stats() -> dict:
    cpu = psutil.cpu_percent(interval=None)

    mem = psutil.virtual_memory()
    ram_used = round(mem.used / (1024**3), 2)
    ram_total = round(mem.total / (1024**3), 2)
    ram = round(mem.percent, 1)

    disk_path = "C:\\" if platform.system() == "Windows" else "/"
    try:
        disk = psutil.disk_usage(disk_path)
        disk_used = round(disk.used / (1024**3), 2)
        disk_total = round(disk.total / (1024**3), 2)
        disk_pct = round(disk.percent, 1)
    except Exception:  # noqa: BLE001
        disk_used, disk_total, disk_pct = 0.0, 0.0, 0.0

    return {
        "cpu": round(float(cpu), 1),
        "cpuCores": os.cpu_count() or 1,
        "ram": ram,
        "ramUsed": ram_used,
        "ramTotal": ram_total,
        "disk": disk_pct,
        "diskUsed": disk_used,
        "diskTotal": disk_total,
        "updatedAt": to_iso_utc(),
    }


def ensure_upload_dirs(base: str | Path) -> Path:
    root = Path(base)
    (root / "avatars").mkdir(parents=True, exist_ok=True)
    return root
