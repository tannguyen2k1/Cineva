import { SignJWT } from 'jose'
import { getTenantPrisma, prisma } from '../../utils/prisma'
import bcrypt from 'bcryptjs'
import { ensureSystemPermissions } from '../../utils/systemPermissions'
import { writeSystemLog } from '../../utils/systemLog'
import { verifyLoginTurnstile } from '../../utils/verifyLoginTurnstile'

const JWT_SECRET_RAW = process.env.JWT_SECRET
if (!JWT_SECRET_RAW) {
  console.error('[SECURITY] JWT_SECRET env is not set.')
}
const JWT_SECRET = new TextEncoder().encode(JWT_SECRET_RAW || '__missing_jwt_secret__')

const ACCESS_TOKEN_TTL = '15m'
const REFRESH_TOKEN_TTL = '7d'
const REFRESH_COOKIE_MAX_AGE = 7 * 24 * 60 * 60 // 7 days in seconds
const ACCESS_COOKIE_MAX_AGE = 15 * 60 // 15 minutes

const IS_PROD = process.env.NODE_ENV === 'production'

defineRouteMeta({
  openAPI: {
    $global: {
      components: {
        securitySchemes: {
          bearerAuth: {
            type: 'http',
            scheme: 'bearer',
            description: 'Access token from login (15 min). Use cookie jar or copy auth_token cookie value.'
          }
        }
      }
    },
    tags: ['Auth'],
    description: 'Login with workspace credentials. Sets httpOnly auth cookies (auth_token, refresh_token).',
    requestBody: {
      required: true,
      content: {
        'application/json': {
          schema: {
            type: 'object',
            required: ['tenant_id', 'username', 'password', 'turnstileToken'],
            properties: {
              tenant_id: { type: 'string', example: 'default' },
              username: { type: 'string' },
              password: { type: 'string', format: 'password' },
              turnstileToken: { type: 'string' }
            }
          }
        }
      }
    }
  }
})

export default defineEventHandler(async (event) => {
  try {
    const body = await readBody(event)
    const { username, password, tenant_id, turnstileToken } = body

    if (!username || !password || !tenant_id) {
      throw createError({ statusCode: 400, statusMessage: 'Thiếu username, password hoặc tenant_id' })
    }

    if (!turnstileToken) {
      throw createError({ statusCode: 400, statusMessage: 'Vui lòng xác minh Cloudflare Turnstile' })
    }

    const turnstile = await verifyLoginTurnstile(turnstileToken, event)
    if (!turnstile.success) {
      throw createError({ statusCode: 403, statusMessage: 'Xác minh Turnstile thất bại' })
    }

    const tenant = await prisma.tenant.findFirst({
      where: { name: tenant_id, deletedAt: null }
    })

    if (!tenant) {
      throw createError({ statusCode: 404, statusMessage: 'Không tìm thấy Workspace này' })
    }

    if (!tenant.isActive) {
      throw createError({ statusCode: 403, statusMessage: 'Workspace đã bị khóa' })
    }

    const tenantDb = getTenantPrisma(tenant.id)
    await ensureSystemPermissions(tenantDb, tenant.id)

    const user = await prisma.user.findFirst({
      where: { username, tenant_id: tenant.id, deletedAt: null },
      include: {
        userRoles: {
          include: {
            role: {
              include: {
                rolePerms: {
                  include: {
                    permission: true
                  }
                }
              }
            }
          }
        }
      }
    })

    if (!user) {
      throw createError({ statusCode: 401, statusMessage: 'Sai username hoặc mật khẩu' })
    }

    if (!user.isActive) {
      throw createError({ statusCode: 403, statusMessage: 'Tài khoản đã bị khóa' })
    }

    const isValid = await bcrypt.compare(password, user.password)
    if (!isValid) {
      throw createError({ statusCode: 401, statusMessage: 'Sai username hoặc mật khẩu' })
    }

    const permissionsSet = new Set<string>()
    if (user.userRoles) {
      user.userRoles.forEach(ur => {
        if (ur.role && ur.role.rolePerms) {
          ur.role.rolePerms.forEach(rp => {
            if (rp.permission) {
              permissionsSet.add(`${rp.permission.action}:${rp.permission.resource}`)
            }
          })
        }
      })
    }
    const permissions = Array.from(permissionsSet)

    const accessToken = await new SignJWT({ userId: user.id, username: user.username, tenant_id: tenant.id })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuedAt()
      .setExpirationTime(ACCESS_TOKEN_TTL)
      .sign(JWT_SECRET)

    const refreshToken = await new SignJWT({ userId: user.id, tenant_id: tenant.id, type: 'refresh' })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuedAt()
      .setExpirationTime(REFRESH_TOKEN_TTL)
      .sign(JWT_SECRET)

    setCookie(event, 'auth_token', accessToken, {
      httpOnly: true,
      secure: IS_PROD,
      sameSite: 'lax',
      path: '/',
      maxAge: ACCESS_COOKIE_MAX_AGE
    })

    setCookie(event, 'refresh_token', refreshToken, {
      httpOnly: true,
      secure: IS_PROD,
      sameSite: 'lax',
      path: '/api/auth',
      maxAge: REFRESH_COOKIE_MAX_AGE
    })

    // Non-httpOnly indicator so client knows auth state (no secret data)
    setCookie(event, 'auth_logged_in', '1', {
      httpOnly: false,
      secure: IS_PROD,
      sameSite: 'lax',
      path: '/',
      maxAge: REFRESH_COOKIE_MAX_AGE
    })

    await writeSystemLog({
      tenant_id: tenant.id,
      user_id: user.id,
      action: 'LOGIN',
      resource: 'Auth',
      details: { username: user.username }
    })

    return {
      success: true,
      data: {
        user: {
          id: user.id,
          username: user.username,
          fullName: user.fullName
        },
        tenant_id: tenant.id,
        permissions
      }
    }
  } catch (error: any) {
    console.error('API Error:', error)
    if (error.statusCode) {
      throw error
    }
    throw createError({
      statusCode: 500,
      statusMessage: 'Lỗi hệ thống',
      message: error.message || 'Đã có lỗi xảy ra',
    })
  }
})
