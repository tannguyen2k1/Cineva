---
name: nuxt-websocket
description: >-
  WebSocket pattern for this monorepo: FastAPI WS + short-lived ticket from /api/auth/ws-ticket,
  Nuxt client connecting via NUXT_PUBLIC_WS_BASE (not Vite proxy).
  Use when adding realtime features, creating WS endpoints, or debugging WS auth failures.
  Triggers on "websocket", "ws", "realtime", "live update", "ws-ticket", "socket".
---

# WebSocket

## Why tickets

httpOnly cookies are not reliably available to browser `WebSocket` constructors the same way as `fetch`.  
Flow: authenticated HTTP → short JWT ticket → connect WS with `?token=`.

## Issue ticket

`GET /api/auth/ws-ticket` (requires access cookie):

```json
{ "ticket": "<jwt type=ws-ticket, 30s>" }
```

Implementation: `backend/app/services/auth.py` → `create_ws_ticket`.

## Server

`backend/app/websocket/server_stats.py` — example:

```python
@router.websocket("/ws/server-stats")
async def server_stats_ws(websocket: WebSocket):
    token = websocket.query_params.get("token")
    payload = safe_decode_token(token)
    if payload.get("type") not in (TOKEN_TYPE_WS, TOKEN_TYPE_ACCESS):
        await websocket.close(code=4001)
        return
    await websocket.accept()
    ...
```

Register router on the FastAPI app (no `/api` prefix for `/ws/...`).

## Client (Nuxt)

```typescript
const { ticket } = await $fetch<{ ticket: string }>('/api/auth/ws-ticket')
const base = String(useRuntimeConfig().public.wsBase).replace(/\/$/, '')
const ws = new WebSocket(`${base}/ws/server-stats?token=${ticket}`)
```

- `wsBase` default: `ws://127.0.0.1:8000` (from `NUXT_API_PROXY` / `NUXT_PUBLIC_WS_BASE`).
- Do **not** rely on Nuxt/Vite proxy for native WebSocket.

## Checklist

- [ ] Ticket endpoint behind access auth
- [ ] WS validates JWT type + userId
- [ ] Client uses `runtimeConfig.public.wsBase`
- [ ] Clean up timers/tasks on disconnect
