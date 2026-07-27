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
    const resource = query.resource as string;
    const action = query.action as string;
    const startDate = query.startDate as string;
    const endDate = query.endDate as string;

    const db = getTenantPrisma(tenant_id);
    const whereCondition: any = {};

    if (search) {
      whereCondition.OR = [
        { action: { contains: search, mode: 'insensitive' } },
        { resource: { contains: search, mode: 'insensitive' } },
        { details: { contains: search, mode: 'insensitive' } }
      ];
    }

    if (resource) whereCondition.resource = resource;
    if (action) whereCondition.action = action;

    if (startDate || endDate) {
      whereCondition.createdAt = {};
      if (startDate) whereCondition.createdAt.gte = new Date(startDate);
      if (endDate) {
        const end = new Date(endDate);
        end.setHours(23, 59, 59, 999);
        whereCondition.createdAt.lte = end;
      }
    }

    const [logs, total] = await Promise.all([
      db.systemLog.findMany({
        where: whereCondition,
        skip: (page - 1) * pageSize,
        take: pageSize,
        orderBy: { createdAt: 'desc' },
        include: {
          user: {
            select: { id: true, username: true, fullName: true }
          }
        }
      }),
      db.systemLog.count({ where: whereCondition })
    ]);

    return {
      success: true,
      data: logs.map(log => ({
        id: log.id,
        action: log.action,
        resource: log.resource,
        details: log.details,
        createdAt: log.createdAt,
        actor: log.user ? log.user.fullName || log.user.username : null,
        actorUsername: log.user?.username || null
      })),
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
      message: error.message || 'Đã có lỗi xảy ra'
    });
  }
});
