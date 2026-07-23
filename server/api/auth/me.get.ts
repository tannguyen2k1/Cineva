import { jwtVerify } from 'jose';
import { prisma } from '../../utils/prisma';

const JWT_SECRET = new TextEncoder().encode(process.env.JWT_SECRET || 'super-secret-key-for-local-dev-only');

export default defineEventHandler(async (event) => {
  // 1. Lấy token từ header hoặc cookie (tùy cách lưu, ở đây Nuxt gửi cookie auth_token)
  let token = getCookie(event, 'auth_token');
  
  if (!token) {
    const authHeader = getHeader(event, 'Authorization');
    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.split(' ')[1];
    }
  }

  if (!token) {
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized - No token' });
  }

  try {
    // 2. Xác thực JWT
    const { payload } = await jwtVerify(token, JWT_SECRET);
    const userId = payload.userId as string;

    // 3. Truy vấn DB lấy user và quyền
    const user = await prisma.user.findUnique({
      where: { id: userId },
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
      throw createError({ statusCode: 401, statusMessage: 'User not found' });
    }

    // 4. Rút trích danh sách quyền
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

    // 5. Trả về
    return {
      success: true,
      data: {
        user: {
          id: user.id,
          username: user.username,
          fullName: user.fullName
        },
        tenant_id: user.tenant_id,
        permissions
      }
    };
  } catch (err) {
    throw createError({ statusCode: 401, statusMessage: 'Invalid or expired token' });
  }
});
