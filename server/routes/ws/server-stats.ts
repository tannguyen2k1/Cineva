import { jwtVerify } from 'jose'
import { getServerStats } from '../../utils/serverStats'

const JWT_SECRET_RAW = process.env.JWT_SECRET
const JWT_SECRET = new TextEncoder().encode(JWT_SECRET_RAW || '__missing_jwt_secret__')

const INTERVAL_MS = 2000
const timers = new Map<string, ReturnType<typeof setInterval>>()

function pushStats(peer: { id: string; send: (data: string) => void }) {
  peer.send(
    JSON.stringify({
      type: 'server-stats',
      data: getServerStats()
    })
  )
}

export default defineWebSocketHandler({
  async open(peer) {
    try {
      const url = peer.url || (peer as any).request?.url || ''
      const tokenMatch = url.match(/[?&]token=([^&]+)/)
      const token = tokenMatch?.[1]

      if (!token) {
        peer.send(JSON.stringify({ type: 'error', message: 'Unauthorized' }))
        peer.close(4001, 'Unauthorized')
        return
      }

      const { payload } = await jwtVerify(token, JWT_SECRET)
      if (!payload.userId || !payload.tenant_id) {
        peer.send(JSON.stringify({ type: 'error', message: 'Invalid token' }))
        peer.close(4001, 'Invalid token')
        return
      }
    } catch {
      peer.send(JSON.stringify({ type: 'error', message: 'Token expired or invalid' }))
      peer.close(4001, 'Token expired or invalid')
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
