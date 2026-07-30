import { getTenantPrisma } from '../../utils/prisma';
import { getActorUserId, writeSystemLog } from '../../utils/systemLog';
import { requirePermission } from '../../utils/requirePermission';

defineRouteMeta({
  openAPI: {
    tags: ['Roles'],
    description: 'Update a role by ID.',
    security: [{ bearerAuth: [] }]
  }
})

export default defineEventHandler(async (event) => {
  try {
    requirePermission(event, 'update:roles');

    const tenant_id = event.context.tenant_id;

    if (!tenant_id) {
      throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' });
    }

    const id = getRouterParam(event, 'id');
    if (!id) {
      throw createError({ statusCode: 400, statusMessage: 'Thiếu id vai trò' });
    }

    const body = await readBody(event);
    const name = body?.name !== undefined ? String(body.name || '').trim() : undefined;
    const description = body?.description !== undefined
      ? (body.description ? String(body.description).trim() : null)
      : undefined;

    if (name !== undefined && !name) {
      throw createError({ statusCode: 400, statusMessage: 'Tên vai trò là bắt buộc' });
    }

    const db = getTenantPrisma(tenant_id);

    const existing = await db.role.findFirst({
      where: { id },
      select: { id: true }
    });

    if (!existing) {
      throw createError({ statusCode: 404, statusMessage: 'Không tìm thấy vai trò' });
    }

    if (name) {
      const duplicate = await db.role.findFirst({
        where: {
          name,
          id: { not: id }
        },
        select: { id: true }
      });

      if (duplicate) {
        throw createError({ statusCode: 409, statusMessage: 'Tên vai trò đã tồn tại trong workspace này' });
      }
    }

    const dataToUpdate: Record<string, unknown> = {};
    if (name !== undefined) dataToUpdate.name = name;
    if (description !== undefined) dataToUpdate.description = description;

    await db.role.updateMany({
      where: { id },
      data: dataToUpdate
    });

    const role = await db.role.findFirst({
      where: { id },
      select: {
        id: true,
        name: true,
        description: true,
        createdAt: true,
        _count: {
          select: {
            userRoles: {
              where: { user: { deletedAt: null } }
            }
          }
        }
      }
    });

    await writeSystemLog({
      tenant_id,
      user_id: getActorUserId(event),
      action: 'UPDATE_ROLE',
      resource: 'Role',
      details: { id: role!.id, name: role!.name }
    });

    return {
      success: true,
      data: {
        id: role!.id,
        name: role!.name,
        description: role!.description,
        createdAt: role!.createdAt,
        userCount: role!._count.userRoles
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
