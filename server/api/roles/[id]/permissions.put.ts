import { getTenantPrisma } from '../../../utils/prisma';
import { getActorUserId, writeSystemLog } from '../../../utils/systemLog';

export default defineEventHandler(async (event) => {
  const tenant_id = event.context.tenant_id;

  if (!tenant_id) {
    throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' });
  }

  const id = getRouterParam(event, 'id');
  if (!id) {
    throw createError({ statusCode: 400, statusMessage: 'Thiếu id vai trò' });
  }

  const body = await readBody(event);
  const permissionIds: string[] = Array.isArray(body?.permissionIds)
    ? body.permissionIds.filter((pid: unknown) => typeof pid === 'string')
    : [];

  const db = getTenantPrisma(tenant_id);

  const role = await db.role.findFirst({
    where: { id },
    select: { id: true, name: true }
  });

  if (!role) {
    throw createError({ statusCode: 404, statusMessage: 'Không tìm thấy vai trò' });
  }

  if (permissionIds.length > 0) {
    const perms = await db.permission.findMany({
      where: { id: { in: permissionIds } },
      select: { id: true }
    });
    if (perms.length !== permissionIds.length) {
      throw createError({ statusCode: 400, statusMessage: 'Một hoặc nhiều quyền không hợp lệ' });
    }
  }

  await db.rolePermission.deleteMany({
    where: { role_id: id }
  });

  if (permissionIds.length > 0) {
    await db.rolePermission.createMany({
      data: permissionIds.map(permission_id => ({
        role_id: id,
        permission_id,
        tenant_id
      }))
    });
  }

  await writeSystemLog({
    tenant_id,
    user_id: getActorUserId(event),
    action: 'UPDATE_ROLE_PERMISSIONS',
    resource: 'Role',
    details: { id: role.id, name: role.name, permissionCount: permissionIds.length }
  });

  return {
    success: true,
    data: {
      roleId: id,
      permissionIds
    }
  };
});
