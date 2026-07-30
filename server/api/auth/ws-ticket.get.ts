import { SignJWT } from 'jose'

const JWT_SECRET_RAW = process.env.JWT_SECRET
const JWT_SECRET = new TextEncoder().encode(JWT_SECRET_RAW || '__missing_jwt_secret__')

defineRouteMeta({
  openAPI: {
    tags: ['Auth'],
    description: 'Issue a short-lived WebSocket ticket JWT (30s).',
    security: [{ bearerAuth: [] }]
  }
})

export default defineEventHandler(async (event) => {
  const userId = event.context.user?.userId as string | undefined
  const tenantId = event.context.tenant_id as string | undefined

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
