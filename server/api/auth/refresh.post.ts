import { jwtVerify, SignJWT } from 'jose'
import { prisma } from '../../utils/prisma'

const JWT_SECRET_RAW = process.env.JWT_SECRET
const JWT_SECRET = new TextEncoder().encode(JWT_SECRET_RAW || '__missing_jwt_secret__')

const ACCESS_TOKEN_TTL = '15m'
const ACCESS_COOKIE_MAX_AGE = 15 * 60
const IS_PROD = process.env.NODE_ENV === 'production'

export default defineEventHandler(async (event) => {
  const refreshToken = getCookie(event, 'refresh_token')
  if (!refreshToken) {
    throw createError({ statusCode: 401, statusMessage: 'No refresh token' })
  }

  try {
    const { payload } = await jwtVerify(refreshToken, JWT_SECRET)

    if (payload.type !== 'refresh') {
      throw createError({ statusCode: 401, statusMessage: 'Invalid token type' })
    }

    const userId = payload.userId as string
    const tenantId = payload.tenant_id as string

    const user = await prisma.user.findFirst({
      where: { id: userId, tenant_id: tenantId, deletedAt: null, isActive: true },
      include: {
        userRoles: {
          include: {
            role: {
              include: {
                rolePerms: {
                  include: { permission: true }
                }
              }
            }
          }
        }
      }
    })

    if (!user) {
      clearAuthCookies(event)
      throw createError({ statusCode: 401, statusMessage: 'User not found or disabled' })
    }

    const permissionsSet = new Set<string>()
    user.userRoles.forEach(ur => {
      ur.role.rolePerms.forEach(rp => {
        if (rp.permission) {
          permissionsSet.add(`${rp.permission.action}:${rp.permission.resource}`)
        }
      })
    })
    const permissions = Array.from(permissionsSet)

    const accessToken = await new SignJWT({ userId: user.id, username: user.username, tenant_id: tenantId })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuedAt()
      .setExpirationTime(ACCESS_TOKEN_TTL)
      .sign(JWT_SECRET)

    setCookie(event, 'auth_token', accessToken, {
      httpOnly: true,
      secure: IS_PROD,
      sameSite: 'lax',
      path: '/',
      maxAge: ACCESS_COOKIE_MAX_AGE
    })

    return {
      success: true,
      data: {
        user: {
          id: user.id,
          username: user.username,
          fullName: user.fullName,
          email: user.email,
          avatar: user.avatar
        },
        tenant_id: tenantId,
        permissions
      }
    }
  } catch (err: any) {
    if (err.statusCode) throw err
    clearAuthCookies(event)
    throw createError({ statusCode: 401, statusMessage: 'Refresh token expired or invalid' })
  }
})

function clearAuthCookies(event: any) {
  const IS_PROD = process.env.NODE_ENV === 'production'
  setCookie(event, 'auth_token', '', { httpOnly: true, secure: IS_PROD, sameSite: 'lax', path: '/', maxAge: 0 })
  setCookie(event, 'refresh_token', '', { httpOnly: true, secure: IS_PROD, sameSite: 'lax', path: '/api/auth', maxAge: 0 })
  setCookie(event, 'auth_logged_in', '', { httpOnly: false, secure: IS_PROD, sameSite: 'lax', path: '/', maxAge: 0 })
}
