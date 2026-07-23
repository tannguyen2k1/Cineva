import { prisma } from '../../utils/prisma';

export default defineEventHandler(async (event) => {
  // Bỏ qua check tenant_id vì query bảng Tenant không phụ thuộc vào Tenant ID
  
  const query = getQuery(event);
  const page = Number(query.page) || 1;
  const pageSize = Number(query.pageSize) || 10;
  const search = query.search as string;
  const status = query.status as string;

  const whereCondition: any = {
    deletedAt: null
  };
  
  if (search) {
    whereCondition.OR = [
      { name: { contains: search, mode: 'insensitive' } },
      { domain: { contains: search, mode: 'insensitive' } }
    ];
  }
  
  if (status === 'active') whereCondition.isActive = true;
  if (status === 'inactive') whereCondition.isActive = false;

  const [tenants, total] = await Promise.all([
    prisma.tenant.findMany({
      where: whereCondition,
      skip: (page - 1) * pageSize,
      take: pageSize,
      select: {
        id: true,
        name: true,
        domain: true,
        isActive: true,
        createdAt: true,
        _count: {
          select: {
            users: { where: { deletedAt: null } }
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    }),
    prisma.tenant.count({ where: whereCondition })
  ]);
  
  const formattedTenants = tenants.map(tenant => ({
    id: tenant.id,
    name: tenant.name,
    domain: tenant.domain,
    userCount: tenant._count.users,
    isActive: tenant.isActive,
    createdAt: tenant.createdAt
  }));

  return {
    success: true,
    data: formattedTenants,
    total,
    page,
    pageSize
  };
});
