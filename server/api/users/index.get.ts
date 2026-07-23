import { getTenantPrisma } from '../../utils/prisma';

export default defineEventHandler(async (event) => {
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
  
  // Format data
  const formattedUsers = users.map(user => {
    // Map all roles to an array of strings
    const roles = user.userRoles.map(ur => ur.role?.name).filter(Boolean);
    if (roles.length === 0) roles.push('User');
    
    return {
      id: user.id,
      username: user.username,
      email: user.email,
      fullName: user.fullName,
      isActive: user.isActive,
      createdAt: user.createdAt,
      roles
    };
  });

  return {
    success: true,
    data: formattedUsers,
    total,
    page,
    pageSize
  };
});
