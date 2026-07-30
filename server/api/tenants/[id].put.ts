import { prisma } from '../../utils/prisma';
import { getActorUserId, writeSystemLog } from '../../utils/systemLog';
import { requirePermission } from '../../utils/requirePermission';

defineRouteMeta({
  openAPI: {
    tags: ['Tenants'],
    description: 'Update a tenant by ID.',
    security: [{ bearerAuth: [] }]
  }
})

export default defineEventHandler(async (event) => {
  try {
    requirePermission(event, 'update:tenants');
    const id = getRouterParam(event, 'id');
    if (!id) {
      throw createError({ statusCode: 400, statusMessage: 'Thiếu id tenant' });
    }

    const body = await readBody(event);
    const name = body?.name !== undefined ? String(body.name || '').trim() : undefined;
    const domain = body?.domain !== undefined
      ? (String(body.domain || '').trim() || null)
      : undefined;
    const isActive = typeof body?.isActive === 'boolean' ? body.isActive : undefined;

    if (name !== undefined && !name) {
      throw createError({ statusCode: 400, statusMessage: 'Tên tenant là bắt buộc' });
    }

    const existing = await prisma.tenant.findFirst({
      where: { id, deletedAt: null },
      select: { id: true }
    });

    if (!existing) {
      throw createError({ statusCode: 404, statusMessage: 'Không tìm thấy tenant' });
    }

    if (name) {
      const duplicate = await prisma.tenant.findFirst({
        where: { name, deletedAt: null, id: { not: id } },
        select: { id: true }
      });
      if (duplicate) {
        throw createError({ statusCode: 409, statusMessage: 'Tên tenant đã tồn tại' });
      }
    }

    if (domain) {
      const duplicateDomain = await prisma.tenant.findFirst({
        where: { domain, id: { not: id } },
        select: { id: true }
      });
      if (duplicateDomain) {
        throw createError({ statusCode: 409, statusMessage: 'Domain / slug đã tồn tại' });
      }
    }

    const currentTenantId = event.context.tenant_id as string | undefined;
    if (isActive === false && currentTenantId === id) {
      throw createError({ statusCode: 400, statusMessage: 'Không thể khóa tenant đang đăng nhập' });
    }

    const dataToUpdate: Record<string, unknown> = {};
    if (name !== undefined) dataToUpdate.name = name;
    if (domain !== undefined) dataToUpdate.domain = domain;
    if (isActive !== undefined) dataToUpdate.isActive = isActive;

    await prisma.tenant.update({
      where: { id },
      data: dataToUpdate
    });

    const tenant = await prisma.tenant.findFirst({
      where: { id },
      select: {
        id: true,
        name: true,
        domain: true,
        isActive: true,
        createdAt: true,
        _count: {
          select: {
            users: { where: { deletedAt: null } }
          }
        }
      }
    });

    await writeSystemLog({
      tenant_id: (event.context.tenant_id as string) || id,
      user_id: getActorUserId(event),
      action: 'UPDATE_TENANT',
      resource: 'Tenant',
      details: {
        id: tenant!.id,
        name: tenant!.name,
        isActive: tenant!.isActive
      }
    });

    return {
      success: true,
      data: {
        id: tenant!.id,
        name: tenant!.name,
        domain: tenant!.domain,
        isActive: tenant!.isActive,
        createdAt: tenant!.createdAt,
        userCount: tenant!._count.users
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
