---
name: nuxt-websocket
description: >-
  WebSocket pattern for this Nuxt 3 SaaS project using Nitro defineWebSocketHandler.
  Covers ticket-based authentication (httpOnly cookies can't be read by WS handlers),
  server handler lifecycle, per-peer timers/cleanup, and native WebSocket client usage.
  Use when adding realtime features (chat, notifications, live stats), creating
  WS endpoints, or debugging WebSocket connection failures.
  Triggers on "websocket", "ws", "realtime", "live update", "defineWebSocketHandler",
  "ws-ticket", "crossws", "socket".
---

# WebSocket Pattern

## Architecture

```
Client                           Server
──────                           ──────
1. GET /api/auth/ws-ticket   →   Issues 30s JWT ticket (auth via httpOnly cookie)
2. new WebSocket(
     ws://host/ws/x?token=T) →   open(peer): verify ticket, start pushing
3. onmessage → update UI     ←   peer.send(JSON.stringify({ type, data }))
4. unmount → ws.close()      →   close(peer): clear timers
```

**Why tickets?** WebSocket handlers cannot read httpOnly cookies reliably.
The client first fetches a short-lived (30s) JWT ticket over an authenticated
HTTP request, then passes it as a query param in the WS URL.

## Prerequisites

Nitro WebSocket is enabled in `nuxt.config.ts`:

```typescript
nitro: {
  experimental: {
    websocket: true
  }
}
```

## Ticket endpoint (already exists)

`server/api/auth/ws-ticket.get.ts` — reuse for all WS endpoints:

```typescript
import { SignJWT } from 'jose'

const JWT_SECRET = new TextEncoder().encode(process.env.JWT_SECRET || '__missing_jwt_secret__')

export default defineEventHandler(async (event) => {
  const userId = event.context.user?.userId
  const tenantId = event.context.tenant_id
  if (!userId || !tenantId) {
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })
  }

  const ticket = await new SignJWT({ userId, tenant_id: tenantId, type: 'ws-ticket' })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('30s')
    .sign(JWT_SECRET)

  return { ticket }
})
```

## Server handler template

Create at `server/routes/ws/{name}.ts` → route `ws://host/ws/{name}`:

```typescript
import { jwtVerify } from 'jose'

const JWT_SECRET = new TextEncoder().encode(process.env.JWT_SECRET || '__missing_jwt_secret__')

// Per-peer state (timers, subscriptions...) keyed by peer.id
const timers = new Map<string, ReturnType<typeof setInterval>>()

function extractToken(peer: any): string | null {
  try {
    // crossws exposes the upgrade request URL differently across versions
    const rawUrl: string = peer.request?.url || peer.websocket?.url || peer.url || ''
    if (!rawUrl) return null
    const url = rawUrl.startsWith('http')
      ? new URL(rawUrl)
      : new URL(rawUrl, 'http://localhost')
    return url.searchParams.get('token')
  } catch {
    return null
  }
}

export default defineWebSocketHandler({
  async open(peer) {
    // 1. Auth — verify ticket BEFORE sending any data
    const token = extractToken(peer)
    if (!token) {
      peer.close(4001, 'Unauthorized')
      return
    }

    let userId: string, tenant_id: string
    try {
      const { payload } = await jwtVerify(token, JWT_SECRET)
      if (!payload.userId || !payload.tenant_id || payload.type !== 'ws-ticket') {
        peer.close(4001, 'Invalid token')
        return
      }
      userId = payload.userId as string
      tenant_id = payload.tenant_id as string
    } catch {
      peer.close(4001, 'Token expired')
      return
    }

    // 2. Start pushing data (example: interval push)
    const timer = setInterval(() => {
      try {
        peer.send(JSON.stringify({ type: 'my-event', data: {} }))
      } catch {
        clearInterval(timer)
        timers.delete(peer.id)
      }
    }, 2000)
    timers.set(peer.id, timer)
  },

  message(peer, message) {
    // Handle incoming messages (chat, commands...)
    // const data = JSON.parse(message.text())
  },

  close(peer) {
    const timer = timers.get(peer.id)
    if (timer) {
      clearInterval(timer)
      timers.delete(peer.id)
    }
  },

  error(peer) {
    // Same cleanup as close
    const timer = timers.get(peer.id)
    if (timer) {
      clearInterval(timer)
      timers.delete(peer.id)
    }
  }
})
```

Key rules:
- **Auth in `open()`**, not `upgrade()` — the `upgrade` hook with `throw new Response()`
  is unreliable in the current Nitro/crossws version.
- Close codes: use `4001` for auth failures (4000-4999 = application-defined).
- Always clean up per-peer state in **both** `close` and `error`.
- Scope data by the `tenant_id` from the verified ticket — never push
  cross-tenant data.

## Client usage (native WebSocket)

Use **native `WebSocket`**, not VueUse `useWebSocket` — the composable's URL
reactivity conflicts with the ticket flow (it auto-connects before the ticket
is fetched).

```typescript
let ws: WebSocket | null = null
const wsConnected = ref(false)

async function connectWs() {
  if (!import.meta.client) return
  try {
    // 1. Get ticket (httpOnly cookie sent automatically)
    const { ticket } = await $fetch<{ ticket: string }>('/api/auth/ws-ticket')

    // 2. Connect with ticket in query param
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
    const url = `${protocol}//${window.location.host}/ws/my-endpoint?token=${ticket}`

    ws = new WebSocket(url)
    ws.onopen = () => { wsConnected.value = true }
    ws.onmessage = (event) => {
      const payload = JSON.parse(typeof event.data === 'string' ? event.data : '')
      if (payload?.type !== 'my-event' || !payload.data) return
      // update state...
    }
    ws.onclose = () => { wsConnected.value = false }
    ws.onerror = () => { wsConnected.value = false }
  } catch {
    console.error('Failed to get WS ticket')
  }
}

function closeWs() {
  if (ws) {
    ws.close()
    ws = null
    wsConnected.value = false
  }
}

onMounted(() => connectWs())
onBeforeUnmount(() => closeWs())
```

## Message format convention

All messages are JSON with a `type` discriminator:

```typescript
{ "type": "server-stats", "data": { ... } }
{ "type": "chat-message", "data": { ... } }
{ "type": "notification", "data": { ... } }
```

Client ignores messages whose `type` it doesn't handle.

## Existing example

`/ws/server-stats` — pushes server CPU/RAM stats every 2s to the dashboard:
- Server: `server/routes/ws/server-stats.ts`
- Client: `pages/index.vue` (`connectWs`, `onWsMessage`)
- Display: `components/ServerStatusCard`

## Checklist

- [ ] Handler at `server/routes/ws/{name}.ts`
- [ ] Ticket verified in `open()` with `jwtVerify` + `type === 'ws-ticket'` check
- [ ] `peer.close(4001, ...)` on auth failure — no data sent before auth passes
- [ ] Per-peer state keyed by `peer.id`, cleaned up in `close` AND `error`
- [ ] Data scoped by `tenant_id` from the verified ticket
- [ ] Client uses native `WebSocket` (not VueUse `useWebSocket`)
- [ ] Client fetches fresh ticket on every (re)connect — tickets expire in 30s
- [ ] Client closes WS in `onBeforeUnmount`
- [ ] Messages are JSON with `type` discriminator
