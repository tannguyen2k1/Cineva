from __future__ import annotations

import argparse
import asyncio
import json

from app.db.session import AsyncSessionLocal
from app.services.film_sync import run_full_sync_now, run_images_sync_now


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Cineva film catalog crawler")
    parser.add_argument("mode", choices=("full", "resume", "images-only"))
    parser.add_argument("--batch-size", type=int, default=50)
    return parser.parse_args()


async def main() -> int:
    args = parse_args()
    async with AsyncSessionLocal() as db:
        if args.mode == "images-only":
            result = await run_images_sync_now(db, batch_size=args.batch_size)
        else:
            result = await run_full_sync_now(db, resume=args.mode == "resume")
    print(json.dumps(result, default=str, ensure_ascii=False, indent=2))
    return 0 if result["success"] else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
