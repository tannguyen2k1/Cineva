import { getTenantPrisma } from '../../../utils/prisma';
import { requirePermission } from '../../../utils/requirePermission';

defineRouteMeta({
  openAPI: {
    tags: ['Roles'],
    description: 'Get permissions assigned to a role.',
    security: [{ bearerAuth: [] }]
  }
})

export default defineEventHandler(async (event) => {
  try {
    requirePermission(event, 'read:roles');

    const tenant_id = event.context.tenant_id;

    if (!tenant_id) {
      throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' });
    }

    const id = getRouterParam(event, 'id');
    if (!id) {
      throw createError({ statusCode: 400, statusMessage: 'Thiếu id vai trò' });
    }

    const db = getTenantPrisma(tenant_id);

    const role = await db.role.findFirst({
      where: { id },
      select: { id: true, name: true }
    });

    if (!role) {
      throw createError({ statusCode: 404, statusMessage: 'Không tìm thấy vai trò' });
    }

    const rolePerms = await db.rolePermission.findMany({
      where: { role_id: id },
      select: { permission_id: true }
    });

    return {
      success: true,
      data: {
        roleId: role.id,
        roleName: role.name,
        permissionIds: rolePerms.map(rp => rp.permission_id)
      }
    };
  } catch (error: any) {
    console.error('API Error:', error);
    if (error.statusCode) {
      throw error;
    }
    throw createError({
      statusCode: 500,
      statusMessage: 'Lỗi hệ thống',
      message: error.message || 'Đã có lỗi xảy ra',
    });
  }
});
