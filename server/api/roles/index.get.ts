import { getTenantPrisma } from '../../utils/prisma';
import { requirePermission } from '../../utils/requirePermission';

export default defineEventHandler(async (event) => {
  try {
    requirePermission(event, 'read:roles');

    const tenant_id = event.context.tenant_id;
    
    if (!tenant_id) {
      throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' });
    }

    const query = getQuery(event);
    const page = Number(query.page) || 1;
    const pageSize = Number(query.pageSize) || 10;
    const search = query.search as string;

    const db = getTenantPrisma(tenant_id);

    const whereCondition: any = {};
    
    if (search) {
      whereCondition.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } }
      ];
    }

    const [roles, total] = await Promise.all([
      db.role.findMany({
        where: whereCondition,
        skip: (page - 1) * pageSize,
        take: pageSize,
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
        },
        orderBy: { createdAt: 'desc' }
      }),
      db.role.count({ where: whereCondition })
    ]);
    
    const formattedRoles = roles.map(role => ({
      id: role.id,
      name: role.name,
      description: role.description,
      userCount: role._count.userRoles,
      createdAt: role.createdAt
    }));

    return {
      success: true,
      data: formattedRoles,
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
