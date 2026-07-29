import { jwtVerify } from 'jose'
import { getServerStats } from '../../utils/serverStats'

const JWT_SECRET_RAW = process.env.JWT_SECRET
const JWT_SECRET = new TextEncoder().encode(JWT_SECRET_RAW || '__missing_jwt_secret__')

const INTERVAL_MS = 2000
const timers = new Map<string, ReturnType<typeof setInterval>>()

function pushStats(peer: any) {
  peer.send(
    JSON.stringify({
      type: 'server-stats',
      data: getServerStats()
    })
  )
}

function extractToken(peer: any): string | null {
  try {
    // crossws exposes the upgrade request on peer
    const rawUrl: string =
      peer.request?.url ||
      peer.websocket?.url ||
      peer.url ||
      ''

    if (!rawUrl) return null

    // rawUrl may be a full URL or just a path
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
    const token = extractToken(peer)

    if (!token) {
      peer.close(4001, 'Unauthorized')
      return
    }

    try {
      const { payload } = await jwtVerify(token, JWT_SECRET)
      if (!payload.userId || !payload.tenant_id) {
        peer.close(4001, 'Invalid token')
        return
      }
    } catch {
      peer.close(4001, 'Token expired')
      return
    }

    pushStats(peer)

    const timer = setInterval(() => {
      try {
        pushStats(peer)
      } catch {
        clearInterval(timer)
        timers.delete(peer.id)
      }
    }, INTERVAL_MS)

    timers.set(peer.id, timer)
  },

  close(peer) {
    const timer = timers.get(peer.id)
    if (timer) {
      clearInterval(timer)
      timers.delete(peer.id)
    }
  },

  error(peer) {
    const timer = timers.get(peer.id)
    if (timer) {
      clearInterval(timer)
      timers.delete(peer.id)
    }
  }
})
