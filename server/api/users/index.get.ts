import { getTenantPrisma } from '../../utils/prisma';

export default defineEventHandler(async (event) => {
  try {
    const tenant_id = event.context.tenant_id;

    if (!tenant_id) {
      throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' });
    }

    const query = getQuery(event);
    const page = Number(query.page) || 1;
    const pageSize = Number(query.pageSize) || 10;
    const search = query.search as string;
    const status = query.status as string;

    const db = getTenantPrisma(tenant_id);

    const whereCondition: any = {};

    if (search) {
      whereCondition.OR = [
        { username: { contains: search, mode: 'insensitive' } },
        { fullName: { contains: search, mode: 'insensitive' } }
      ];
    }

    if (status === 'active') whereCondition.isActive = true;
    if (status === 'inactive') whereCondition.isActive = false;

    const [users, total] = await Promise.all([
      db.user.findMany({
        where: whereCondition,
        skip: (page - 1) * pageSize,
        take: pageSize,
        select: {
          id: true,
          username: true,
          email: true,
          fullName: true,
          avatar: true,
          isActive: true,
          createdAt: true,
          userRoles: {
            include: {
              role: true
            }
          }
        },
        orderBy: { createdAt: 'desc' }
      }),
      db.user.count({ where: whereCondition })
    ]);

    const formattedUsers = users.map(user => {
      const roleIds = user.userRoles
        .map(ur => ur.role?.id)
        .filter(Boolean) as string[];
      const roles = user.userRoles
        .map(ur => ur.role?.name)
        .filter(Boolean) as string[];
      if (roles.length === 0) roles.push('User');

      return {
        id: user.id,
        username: user.username,
        email: user.email,
        fullName: user.fullName,
        avatar: user.avatar,
        isActive: user.isActive,
        createdAt: user.createdAt,
        roles,
        roleIds
      };
    });

    return {
      success: true,
      data: formattedUsers,
      total,
      page,
      pageSize
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
