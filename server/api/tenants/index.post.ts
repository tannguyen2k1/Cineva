import bcrypt from 'bcryptjs';
import { prisma, getTenantPrisma } from '../../utils/prisma';
import { ensureSystemPermissions } from '../../utils/systemPermissions';
import { getActorUserId, writeSystemLog } from '../../utils/systemLog';
import { getDefaultAdminCredentials } from '../../utils/defaultAdmin';

export default defineEventHandler(async (event) => {
  const body = await readBody(event);
  const name = String(body?.name || '').trim();
  const domainRaw = body?.domain != null ? String(body.domain).trim() : '';
  const domain = domainRaw || null;
  const isActive = body?.isActive !== false;
  const { username: adminUsername, password: adminPassword } = getDefaultAdminCredentials();

  if (!name) {
    throw createError({ statusCode: 400, statusMessage: 'Tên tenant là bắt buộc' });
  }

  const existingName = await prisma.tenant.findFirst({
    where: { name, deletedAt: null },
    select: { id: true }
  });

  if (existingName) {
    throw createError({ statusCode: 409, statusMessage: 'Tên tenant đã tồn tại' });
  }

  if (domain) {
    const existingDomain = await prisma.tenant.findFirst({
      where: { domain },
      select: { id: true }
    });
    if (existingDomain) {
      throw createError({ statusCode: 409, statusMessage: 'Domain / slug đã tồn tại' });
    }
  }

  const tenant = await prisma.tenant.create({
    data: {
      name,
      domain,
      isActive
    },
    select: {
      id: true,
      name: true,
      domain: true,
      isActive: true,
      createdAt: true
    }
  });

  const db = getTenantPrisma(tenant.id);
  await ensureSystemPermissions(db, tenant.id);

  let adminRole = await db.role.findFirst({
    where: { name: 'Admin' },
    select: { id: true }
  });

  if (!adminRole) {
    adminRole = await db.role.create({
      data: {
        name: 'Admin',
        description: 'Quản trị viên hệ thống',
        tenant_id: tenant.id
      },
      select: { id: true }
    });
    await ensureSystemPermissions(db, tenant.id);
  }

  const hashedPassword = await bcrypt.hash(adminPassword, 10);
  const adminUser = await db.user.create({
    data: {
      username: adminUsername,
      password: hashedPassword,
      fullName: 'Super Admin',
      isActive: true,
      tenant_id: tenant.id,
      userRoles: {
        create: {
          role_id: adminRole.id,
          tenant_id: tenant.id
        }
      }
    },
    select: { id: true, username: true }
  });

  const actorTenantId = event.context.tenant_id as string | undefined;
  if (actorTenantId) {
    await writeSystemLog({
      tenant_id: actorTenantId,
      user_id: getActorUserId(event),
      action: 'CREATE_TENANT',
      resource: 'Tenant',
      details: {
        id: tenant.id,
        name: tenant.name,
        domain: tenant.domain,
        defaultAdmin: adminUser.username
      }
    });
  }

  return {
    success: true,
    data: {
      ...tenant,
      userCount: 1,
      defaultAdmin: {
        username: adminUsername,
        password: adminPassword
      }
    }
  };
});
