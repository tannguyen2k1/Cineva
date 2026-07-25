import { getTenantPrisma } from '../../utils/prisma';
import { getActorUserId, writeSystemLog } from '../../utils/systemLog';

export default defineEventHandler(async (event) => {
  try {
    const tenant_id = event.context.tenant_id;
    const currentUser = event.context.user as { userId?: string } | undefined;

    if (!tenant_id) {
      throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' });
    }

    const id = getRouterParam(event, 'id');
    if (!id) {
      throw createError({ statusCode: 400, statusMessage: 'Thiếu id người dùng' });
    }

    if (currentUser?.userId && currentUser.userId === id) {
      throw createError({ statusCode: 400, statusMessage: 'Không thể xóa tài khoản đang đăng nhập' });
    }

    const db = getTenantPrisma(tenant_id);

    const existing = await db.user.findFirst({
      where: { id },
      select: { id: true, username: true }
    });

    if (!existing) {
      throw createError({ statusCode: 404, statusMessage: 'Không tìm thấy người dùng' });
    }

    await db.user.updateMany({
      where: { id },
      data: {
        deletedAt: new Date(),
        isActive: false
      }
    });

    await writeSystemLog({
      tenant_id,
      user_id: getActorUserId(event),
      action: 'DELETE_USER',
      resource: 'User',
      details: { id: existing.id, username: existing.username }
    });

    return {
      success: true,
      message: 'Đã xóa người dùng'
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
