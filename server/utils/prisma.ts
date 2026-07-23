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

/** Models hỗ trợ soft delete (cột deletedAt) */
const SOFT_DELETE_MODELS = new Set(['User', 'Role', 'Tenant']);

function withSoftDeleteFilter(args: any) {
  const where = args?.where ?? {};
  if (where.deletedAt === undefined) {
    return { ...args, where: { ...where, deletedAt: null } };
  }
  return args;
}

/**
 * Tạo Prisma Client gắn tenant_id + ẩn bản ghi soft-deleted.
 * Lưu ý: update/delete/findUnique dùng WhereUniqueInput — không inject tenant_id
 * vào where (sẽ phá unique). API cần verify ownership bằng findFirst trước.
 */
export function getTenantPrisma(tenant_id: string) {
  if (!tenant_id) {
    throw new Error('tenant_id is required to access the database safely');
  }

  return prisma.$extends({
    query: {
      $allModels: {
        async $allOperations({ model, operation, args, query }) {
          const dynamicArgs = args as any;

          if (
            SOFT_DELETE_MODELS.has(model) &&
            ['findFirst', 'findMany', 'count', 'aggregate', 'groupBy'].includes(operation)
          ) {
            Object.assign(dynamicArgs, withSoftDeleteFilter(dynamicArgs));
          }

          if (model === 'Tenant') {
            return query(dynamicArgs);
          }

          // where không-unique: an toàn khi thêm tenant_id
          if (['findFirst', 'findMany', 'count', 'updateMany', 'deleteMany'].includes(operation)) {
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
