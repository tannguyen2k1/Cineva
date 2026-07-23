import { PrismaClient } from '../../generated/prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';

const connectionString = process.env.DATABASE_URL;

const pool = new Pool({ connectionString });
const adapter = new PrismaPg(pool);

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma = globalForPrisma.prisma ?? new PrismaClient({ adapter });

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;

/**
 * Tạo một Prisma Client instance có gắn Extension tự động lọc tenant_id.
 * Hàm này sẽ được gọi ở Middleware hoặc trong API sau khi đã xác định được tenant_id của request.
 */
export function getTenantPrisma(tenant_id: string) {
  if (!tenant_id) {
    throw new Error('tenant_id is required to access the database safely');
  }

  return prisma.$extends({
    query: {
      $allModels: {
        async $allOperations({ model, operation, args, query }) {
          // Bỏ qua model Tenant vì bảng Tenant không có cột tenant_id (chỉ có id)
          if (model === 'Tenant') {
            return query(args);
          }

          const dynamicArgs = args as any;
          // Tự động gài tenant_id vào các câu lệnh điều kiện (where, data)
          if (['findUnique', 'findFirst', 'findMany', 'count', 'update', 'updateMany', 'delete', 'deleteMany'].includes(operation)) {
            dynamicArgs.where = { ...dynamicArgs.where, tenant_id };
          }
          if (['create', 'createMany'].includes(operation)) {
            if (Array.isArray(dynamicArgs.data)) {
              dynamicArgs.data = dynamicArgs.data.map((d: any) => ({ ...d, tenant_id }));
            } else {
              dynamicArgs.data = { ...dynamicArgs.data, tenant_id };
            }
          }

          return query(dynamicArgs);
        }
      }
    }
  });
}
