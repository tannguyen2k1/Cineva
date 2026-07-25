import { prisma } from '../../utils/prisma';
import { getActorUserId, writeSystemLog } from '../../utils/systemLog';

export default defineEventHandler(async (event) => {
  try {
    const id = getRouterParam(event, 'id');
    if (!id) {
      throw createError({ statusCode: 400, statusMessage: 'Thiếu id tenant' });
    }

    const currentTenantId = event.context.tenant_id as string | undefined;
    if (currentTenantId && currentTenantId === id) {
      throw createError({ statusCode: 400, statusMessage: 'Không thể xóa tenant đang đăng nhập' });
    }

    const existing = await prisma.tenant.findFirst({
      where: { id, deletedAt: null },
      select: {
        id: true,
        name: true,
        domain: true,
        _count: {
          select: {
            users: { where: { deletedAt: null } }
          }
        }
      }
    });

    if (!existing) {
      throw createError({ statusCode: 404, statusMessage: 'Không tìm thấy tenant' });
    }

    if (existing._count.users > 0) {
      throw createError({
        statusCode: 400,
        statusMessage: `Không thể xóa: còn ${existing._count.users} người dùng trong tenant này`
      });
    }

    await prisma.tenant.update({
      where: { id },
      data: {
        deletedAt: new Date(),
        isActive: false,
        domain: existing.domain
          ? `${existing.domain}__deleted__${id.slice(0, 8)}`
          : existing.domain
      }
    });

    if (currentTenantId) {
      await writeSystemLog({
        tenant_id: currentTenantId,
        user_id: getActorUserId(event),
        action: 'DELETE_TENANT',
        resource: 'Tenant',
        details: { id: existing.id, name: existing.name }
      });
    }

    return {
      success: true,
      message: 'Đã xóa tenant'
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
