import bcrypt from 'bcryptjs';
import { getTenantPrisma } from '../../utils/prisma';

export default defineEventHandler(async (event) => {
  const tenant_id = event.context.tenant_id;

  if (!tenant_id) {
    throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' });
  }

  const id = getRouterParam(event, 'id');
  if (!id) {
    throw createError({ statusCode: 400, statusMessage: 'Thiếu id người dùng' });
  }

  const body = await readBody(event);
  const fullName = body?.fullName !== undefined
    ? (body.fullName ? String(body.fullName).trim() : null)
    : undefined;
  const email = body?.email !== undefined
    ? (body.email ? String(body.email).trim() : null)
    : undefined;
  const isActive = typeof body?.isActive === 'boolean' ? body.isActive : undefined;
  const password = body?.password ? String(body.password) : undefined;
  const roleIds = Array.isArray(body?.roleIds)
    ? body.roleIds.filter((rid: unknown) => typeof rid === 'string') as string[]
    : undefined;

  if (password !== undefined && password.length < 6) {
    throw createError({ statusCode: 400, statusMessage: 'Mật khẩu phải có ít nhất 6 ký tự' });
  }

  const db = getTenantPrisma(tenant_id);

  const existing = await db.user.findFirst({
    where: { id },
    select: { id: true }
  });

  if (!existing) {
    throw createError({ statusCode: 404, statusMessage: 'Không tìm thấy người dùng' });
  }

  if (roleIds) {
    if (roleIds.length > 0) {
      const roles = await db.role.findMany({
        where: { id: { in: roleIds } },
        select: { id: true }
      });
      if (roles.length !== roleIds.length) {
        throw createError({ statusCode: 400, statusMessage: 'Một hoặc nhiều vai trò không hợp lệ' });
      }
    }

    await db.userRole.deleteMany({
      where: { user_id: id }
    });
  }

  const dataToUpdate: Record<string, unknown> = {};
  if (fullName !== undefined) dataToUpdate.fullName = fullName;
  if (email !== undefined) dataToUpdate.email = email;
  if (isActive !== undefined) dataToUpdate.isActive = isActive;
  if (password) dataToUpdate.password = await bcrypt.hash(password, 10);

  if (roleIds) {
    dataToUpdate.userRoles = {
      create: roleIds.map(role_id => ({
        role_id,
        tenant_id
      }))
    };
  }

  const user = await db.user.update({
    where: { id },
    data: dataToUpdate,
    select: {
      id: true,
      username: true,
      email: true,
      fullName: true,
      avatar: true,
      isActive: true,
      createdAt: true,
      userRoles: {
        include: { role: true }
      }
    }
  });

  const roles = user.userRoles
    .map((ur: { role?: { name?: string | null } | null }) => ur.role?.name)
    .filter(Boolean) as string[];
  const updatedRoleIds = user.userRoles
    .map((ur: { role?: { id?: string | null } | null }) => ur.role?.id)
    .filter(Boolean) as string[];

  return {
    success: true,
    data: {
      id: user.id,
      username: user.username,
      email: user.email,
      fullName: user.fullName,
      avatar: user.avatar,
      isActive: user.isActive,
      createdAt: user.createdAt,
      roles: roles.length ? roles : ['User'],
      roleIds: updatedRoleIds
    }
  };
});
