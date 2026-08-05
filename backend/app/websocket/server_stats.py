from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.core.security import safe_decode_token
from app.services.server_stats import get_server_stats
import asyncio

router = APIRouter()


@router.websocket("/ws/server-stats")
async def server_stats_ws(websocket: WebSocket):
    token = websocket.query_params.get("token")
    payload = safe_decode_token(token) if token else None
    if not payload or not payload.get("userId") or not payload.get("tenant_id"):
        await websocket.close(code=4001)
        return

    await websocket.accept()
    try:
        while True:
            await websocket.send_json({"type": "server-stats", "data": get_server_stats()})
            await asyncio.sleep(2)
    except WebSocketDisconnect:
        return
    except Exception:
        await websocket.close()
