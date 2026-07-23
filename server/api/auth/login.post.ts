import { SignJWT } from 'jose';
import { getTenantPrisma, prisma } from '../../utils/prisma';
import bcrypt from 'bcryptjs';
import { ensureSystemPermissions } from '../../utils/systemPermissions';
import { writeSystemLog } from '../../utils/systemLog';
import { verifyLoginTurnstile } from '../../utils/verifyLoginTurnstile';

const JWT_SECRET = new TextEncoder().encode(process.env.JWT_SECRET || 'super-secret-key-for-local-dev-only');

export default defineEventHandler(async (event) => {
  const body = await readBody(event);
  const { username, password, tenant_id, turnstileToken } = body;

  if (!username || !password || !tenant_id) {
    throw createError({ statusCode: 400, statusMessage: 'Thiếu username, password hoặc tenant_id' });
  }

  if (!turnstileToken) {
    throw createError({ statusCode: 400, statusMessage: 'Vui lòng xác minh Cloudflare Turnstile' });
  }

  const turnstile = await verifyLoginTurnstile(turnstileToken, event);
  if (!turnstile.success) {
    throw createError({ statusCode: 403, statusMessage: 'Xác minh Turnstile thất bại' });
  }

  // Tìm Tenant theo name (người dùng nhập tên workspace thay vì UUID)
  const tenant = await prisma.tenant.findFirst({
    where: { name: tenant_id, deletedAt: null } // frontend gửi tenant_id nhưng thực chất là name
  });

  if (!tenant) {
    throw createError({ statusCode: 404, statusMessage: 'Không tìm thấy Workspace này' });
  }

  if (!tenant.isActive) {
    throw createError({ statusCode: 403, statusMessage: 'Workspace đã bị khóa' });
  }

  // Sync catalog quyền theo module + đảm bảo role Admin đủ quyền
  const tenantDb = getTenantPrisma(tenant.id);
  await ensureSystemPermissions(tenantDb, tenant.id);

  // Lấy user theo tenant_id thực tế và kèm theo quyền (bỏ qua soft-deleted)
  const user = await prisma.user.findFirst({
    where: { username, tenant_id: tenant.id, deletedAt: null },
    include: {
      userRoles: {
        include: {
          role: {
            include: {
              rolePerms: {
                include: {
                  permission: true
                }
              }
            }
          }
        }
      }
    }
  });

  if (!user) {
    throw createError({ statusCode: 401, statusMessage: 'Sai username hoặc mật khẩu' });
  }

  if (!user.isActive) {
    throw createError({ statusCode: 403, statusMessage: 'Tài khoản đã bị khóa' });
  }

  // Kiểm tra password
  const isValid = await bcrypt.compare(password, user.password);
  if (!isValid) {
    throw createError({ statusCode: 401, statusMessage: 'Sai username hoặc mật khẩu' });
  }

  // Rút trích danh sách quyền thành mảng string (VD: 'read:users')
  const permissionsSet = new Set<string>();
  if (user.userRoles) {
    user.userRoles.forEach(ur => {
      if (ur.role && ur.role.rolePerms) {
        ur.role.rolePerms.forEach(rp => {
          if (rp.permission) {
            permissionsSet.add(`${rp.permission.action}:${rp.permission.resource}`);
          }
        });
      }
    });
  }
  const permissions = Array.from(permissionsSet);

  // Tạo token JWT
  const token = await new SignJWT({ userId: user.id, username: user.username, tenant_id: tenant.id })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('2h')
    .sign(JWT_SECRET);

  await writeSystemLog({
    tenant_id: tenant.id,
    user_id: user.id,
    action: 'LOGIN',
    resource: 'Auth',
    details: { username: user.username }
  });

  return {
    success: true,
    data: {
      user: {
        id: user.id,
        username: user.username,
        fullName: user.fullName
      },
      tenant_id: tenant.id,
      token,
      permissions
    }
  };
});
