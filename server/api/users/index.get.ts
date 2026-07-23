import { getTenantPrisma } from '../../utils/prisma';

export default defineEventHandler(async (event) => {
  // Lấy tenant_id từ context (đã được middleware parse từ header)
  const tenant_id = event.context.tenant_id;
  
  if (!tenant_id) {
    throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' });
  }

  // Khởi tạo prisma an toàn (chỉ lấy data của đúng tenant_id này)
  const db = getTenantPrisma(tenant_id);

  // Nhờ Prisma Client Extension, câu query findMany này sẽ TỰ ĐỘNG thêm điều kiện `where: { tenant_id }`
  const users = await db.user.findMany({
    select: {
      id: true,
      email: true,
      fullName: true,
      isActive: true,
      createdAt: true
    }
  });

  return {
    success: true,
    data: users
  };
});
