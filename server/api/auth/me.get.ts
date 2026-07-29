import { prisma } from '../../utils/prisma'

export default defineEventHandler(async (event) => {
  const userId = event.context.user?.userId as string | undefined
  const tenantId = event.context.tenant_id as string | undefined

  if (!userId || !tenantId) {
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })
  }

  const user = await prisma.user.findFirst({
    where: { id: userId, tenant_id: tenantId, deletedAt: null },
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
    throw createError({ statusCode: 401, statusMessage: 'User not found' })
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
      tenant_id: user.tenant_id,
      permissions
    }
  }
})
