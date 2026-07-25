import { getTenantPrisma } from '../../utils/prisma';
import { getActorUserId, writeSystemLog } from '../../utils/systemLog';

export default defineEventHandler(async (event) => {
  try {
    const tenant_id = event.context.tenant_id;

    if (!tenant_id) {
      throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' });
    }

    const id = getRouterParam(event, 'id');
    if (!id) {
      throw createError({ statusCode: 400, statusMessage: 'Thiếu id vai trò' });
    }

    const db = getTenantPrisma(tenant_id);

    const existing = await db.role.findFirst({
      where: { id },
      select: {
        id: true,
        name: true,
        _count: {
          select: {
            userRoles: {
              where: { user: { deletedAt: null } }
            }
          }
        }
      }
    });

    if (!existing) {
      throw createError({ statusCode: 404, statusMessage: 'Không tìm thấy vai trò' });
    }

    if (existing._count.userRoles > 0) {
      throw createError({
        statusCode: 400,
        statusMessage: `Không thể xóa: còn ${existing._count.userRoles} người dùng đang dùng vai trò này`
      });
    }

    await db.role.updateMany({
      where: { id },
      data: { deletedAt: new Date() }
    });

    await writeSystemLog({
      tenant_id,
      user_id: getActorUserId(event),
      action: 'DELETE_ROLE',
      resource: 'Role',
      details: { id: existing.id, name: existing.name }
    });

    return {
      success: true,
      message: 'Đã xóa vai trò'
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
