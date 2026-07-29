import { getTenantPrisma } from '../../utils/prisma';
import { getActorUserId, writeSystemLog } from '../../utils/systemLog';
import { requirePermission } from '../../utils/requirePermission';

export default defineEventHandler(async (event) => {
  try {
    requirePermission(event, 'create:roles');

    const tenant_id = event.context.tenant_id;

    if (!tenant_id) {
      throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' });
    }

    const body = await readBody(event);
    const name = String(body?.name || '').trim();
    const description = body?.description != null
      ? String(body.description).trim() || null
      : null;

    if (!name) {
      throw createError({ statusCode: 400, statusMessage: 'Tên vai trò là bắt buộc' });
    }

    const db = getTenantPrisma(tenant_id);

    const existing = await db.role.findFirst({
      where: { name }
    });

    if (existing) {
      throw createError({ statusCode: 409, statusMessage: 'Tên vai trò đã tồn tại trong workspace này' });
    }

    const role = await db.role.create({
      data: {
        name,
        description,
        tenant_id
      },
      select: {
        id: true,
        name: true,
        description: true,
        createdAt: true
      }
    });

    await writeSystemLog({
      tenant_id,
      user_id: getActorUserId(event),
      action: 'CREATE_ROLE',
      resource: 'Role',
      details: { id: role.id, name: role.name }
    });

    return {
      success: true,
      data: {
        ...role,
        userCount: 0
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
