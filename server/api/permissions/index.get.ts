import { getTenantPrisma } from '../../utils/prisma';
import {
  ACTION_LABELS,
  SYSTEM_MODULES,
  ensureSystemPermissions,
  permissionKey,
  type PermissionAction
} from '../../utils/systemPermissions';

export default defineEventHandler(async (event) => {
  try {
    const tenant_id = event.context.tenant_id;

    if (!tenant_id) {
      throw createError({ statusCode: 400, statusMessage: 'Missing tenant_id context' });
    }

    const db = getTenantPrisma(tenant_id);
    await ensureSystemPermissions(db, tenant_id);

    const permissions = await db.permission.findMany({
      select: {
        id: true,
        action: true,
        resource: true,
        description: true
      }
    });

    const byKey = new Map(
      permissions.map(p => [permissionKey(p.action, p.resource), p])
    );

    // Trả về đúng thứ tự / nhóm theo SYSTEM_MODULES (bỏ quyền lạc ngoài catalog)
    const data = SYSTEM_MODULES.map(mod => ({
      resource: mod.key,
      label: mod.label,
      permissions: mod.permissions
        .map(def => {
          const row = byKey.get(permissionKey(def.action, mod.key));
          if (!row) return null;
          return {
            id: row.id,
            action: row.action,
            actionLabel: ACTION_LABELS[row.action as PermissionAction] || row.action,
            key: permissionKey(row.action, row.resource),
            description: row.description || def.description
          };
        })
        .filter(Boolean)
    })).filter(group => group.permissions.length > 0);

    return {
      success: true,
      data
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
