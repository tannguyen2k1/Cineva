import { jwtVerify } from 'jose'
import { prisma } from '../utils/prisma'

const JWT_SECRET_RAW = process.env.JWT_SECRET
if (!JWT_SECRET_RAW) {
  console.error('[SECURITY] JWT_SECRET env is not set — refusing to start with a hardcoded fallback.')
}
const JWT_SECRET = new TextEncoder().encode(JWT_SECRET_RAW || '__missing_jwt_secret__')

/** Routes that don't require authentication */
const PUBLIC_ROUTES = ['/api/auth/login', '/api/auth/register', '/api/auth/refresh', '/api/auth/logout']

export default defineEventHandler(async (event) => {
  const pathname = getRequestURL(event).pathname
  if (!pathname.startsWith('/api/')) return
  if (PUBLIC_ROUTES.some(r => pathname.startsWith(r))) return

  const token = extractToken(event)
  if (!token) {
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })
  }

  try {
    const { payload } = await jwtVerify(token, JWT_SECRET)

    const userId = payload.userId as string
    const tenantId = payload.tenant_id as string

    if (!userId || !tenantId) {
      throw createError({ statusCode: 401, statusMessage: 'Unauthorized: Malformed token' })
    }

    const user = await prisma.user.findFirst({
      where: { id: userId, tenant_id: tenantId, deletedAt: null, isActive: true },
      select: {
        id: true,
        username: true,
        tenant_id: true,
        userRoles: {
          select: {
            role: {
              select: {
                rolePerms: {
                  select: {
                    permission: {
                      select: { action: true, resource: true }
                    }
                  }
                }
              }
            }
          }
        }
      }
    })

    if (!user) {
      throw createError({ statusCode: 401, statusMessage: 'Unauthorized: User not found or disabled' })
    }

    const permissions = new Set<string>()
    for (const ur of user.userRoles) {
      for (const rp of ur.role.rolePerms) {
        permissions.add(`${rp.permission.action}:${rp.permission.resource}`)
      }
    }

    event.context.user = { userId: user.id, username: user.username }
    event.context.tenant_id = user.tenant_id
    event.context.permissions = permissions
  } catch (err: any) {
    if (err.statusCode) throw err
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized: Token expired or invalid' })
  }
})

function extractToken(event: any): string | null {
  // 1. httpOnly cookie (preferred)
  const cookieToken = getCookie(event, 'auth_token')
  if (cookieToken) return cookieToken

  // 2. Authorization header fallback (API clients)
  const authHeader = getHeader(event, 'authorization')
  if (authHeader?.startsWith('Bearer ')) {
    return authHeader.slice(7) || null
  }

  return null
}
