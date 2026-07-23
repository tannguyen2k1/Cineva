import { getTenantPrisma } from '../../utils/prisma';
import { getServerStats } from '../../utils/serverStats';

export default defineEventHandler(async (event) => {
  const tenant_id = event.context.tenant_id;

  if (!tenant_id) {
    throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' });
  }

  const db = getTenantPrisma(tenant_id);

  const [userCount, roleCount, tenantCount, logCount, recentLogs, recentUsers] = await Promise.all([
    db.user.count(),
    db.role.count(),
    db.tenant.count(),
    db.systemLog.count(),
    db.systemLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: 20,
      include: {
        user: {
          select: { fullName: true, username: true }
        }
      }
    }),
    db.user.findMany({
      orderBy: { createdAt: 'desc' },
      take: 4,
      select: {
        id: true,
        username: true,
        fullName: true,
        avatar: true,
        createdAt: true
      }
    })
  ]);

  return {
    success: true,
    data: {
      stats: {
        users: userCount,
        roles: roleCount,
        tenants: tenantCount,
        logs: logCount
      },
      recentLogs: recentLogs.map(log => ({
        id: log.id,
        action: log.action,
        details: log.details || (log.user ? `Bởi ${log.user.fullName || log.user.username}` : 'Hệ thống'),
        createdAt: log.createdAt,
        type: log.action.includes('LỖI') ? 'danger' : (log.action.includes('CẢNH BÁO') ? 'warning' : 'primary')
      })),
      server: getServerStats(),
      recentUsers: recentUsers
    }
  };
});
