import bcrypt from 'bcryptjs';
import { getTenantPrisma } from '../../utils/prisma';
import { getActorUserId, writeSystemLog } from '../../utils/systemLog';
import { requirePermission } from '../../utils/requirePermission';

export default defineEventHandler(async (event) => {
  try {
    requirePermission(event, 'create:users');

    const tenant_id = event.context.tenant_id;

    if (!tenant_id) {
      throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' });
    }

    const body = await readBody(event);
    const username = String(body?.username || '').trim();
    const password = String(body?.password || '');
    const fullName = body?.fullName ? String(body.fullName).trim() : null;
    const email = body?.email ? String(body.email).trim() : null;
    const isActive = body?.isActive !== false;
    const roleIds: string[] = Array.isArray(body?.roleIds)
      ? body.roleIds.filter((id: unknown) => typeof id === 'string')
      : [];

    if (!username || !password) {
      throw createError({ statusCode: 400, statusMessage: 'Username và mật khẩu là bắt buộc' });
    }

    if (password.length < 6) {
      throw createError({ statusCode: 400, statusMessage: 'Mật khẩu phải có ít nhất 6 ký tự' });
    }

    const db = getTenantPrisma(tenant_id);

    const existing = await db.user.findFirst({
      where: { username }
    });

    if (existing) {
      throw createError({ statusCode: 409, statusMessage: 'Username đã tồn tại trong workspace này' });
    }

    if (roleIds.length > 0) {
      const roles = await db.role.findMany({
        where: { id: { in: roleIds } },
        select: { id: true }
      });
      if (roles.length !== roleIds.length) {
        throw createError({ statusCode: 400, statusMessage: 'Một hoặc nhiều vai trò không hợp lệ' });
      }
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await db.user.create({
      data: {
        username,
        password: hashedPassword,
        fullName,
        email,
        isActive,
        tenant_id,
        userRoles: roleIds.length
          ? {
              create: roleIds.map(role_id => ({
                role_id,
                tenant_id
              }))
            }
          : undefined
      },
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

    const roles = user.userRoles.map(ur => ur.role?.name).filter(Boolean) as string[];
    const createdRoleIds = user.userRoles.map(ur => ur.role?.id).filter(Boolean) as string[];

    await writeSystemLog({
      tenant_id,
      user_id: getActorUserId(event),
      action: 'CREATE_USER',
      resource: 'User',
      details: { id: user.id, username: user.username }
    });

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
        roleIds: createdRoleIds
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
