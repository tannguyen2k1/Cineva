export type PermissionAction = 'read' | 'create' | 'update' | 'delete';

export interface ModulePermissionDef {
  action: PermissionAction;
  description: string;
}

export interface SystemModuleDef {
  /** resource trong DB + key runtime: `${action}:${key}` */
  key: string;
  label: string;
  permissions: ModulePermissionDef[];
}

/**
 * Catalog quyền theo module.
 * Runtime format: `${action}:${module.key}` — ví dụ `read:users`, `delete:roles`.
 */
export const SYSTEM_MODULES: SystemModuleDef[] = [
  {
    key: 'dashboard',
    label: 'Dashboard',
    permissions: [
      { action: 'read', description: 'Xem trang tổng quan' }
    ]
  },
  {
    key: 'users',
    label: 'Người dùng',
    permissions: [
      { action: 'read', description: 'Xem danh sách người dùng' },
      { action: 'create', description: 'Tạo người dùng' },
      { action: 'update', description: 'Sửa / khóa người dùng' },
      { action: 'delete', description: 'Xóa người dùng (soft delete)' }
    ]
  },
  {
    key: 'roles',
    label: 'Vai trò',
    permissions: [
      { action: 'read', description: 'Xem danh sách vai trò' },
      { action: 'create', description: 'Tạo vai trò' },
      { action: 'update', description: 'Sửa vai trò và phân quyền' },
      { action: 'delete', description: 'Xóa vai trò (soft delete)' }
    ]
  },
  {
    key: 'tenants',
    label: 'Tenant',
    permissions: [
      { action: 'read', description: 'Xem danh sách tenant' },
      { action: 'create', description: 'Tạo tenant' },
      { action: 'update', description: 'Sửa / khóa tenant' },
      { action: 'delete', description: 'Xóa tenant (soft delete)' }
    ]
  },
  {
    key: 'logs',
    label: 'Nhật ký',
    permissions: [
      { action: 'read', description: 'Xem nhật ký hệ thống' }
    ]
  }
];

export const ACTION_LABELS: Record<PermissionAction, string> = {
  read: 'Xem',
  create: 'Tạo',
  update: 'Sửa',
  delete: 'Xóa'
};

/** Flatten catalog → danh sách permission để sync DB */
export const SYSTEM_PERMISSIONS = SYSTEM_MODULES.flatMap(mod =>
  mod.permissions.map(p => ({
    action: p.action,
    resource: mod.key,
    description: p.description,
    moduleLabel: mod.label
  }))
);

export const RESOURCE_LABELS: Record<string, string> = Object.fromEntries(
  SYSTEM_MODULES.map(m => [m.key, m.label])
);

export function permissionKey(action: string, resource: string) {
  return `${action}:${resource}`;
}

/** Đảm bảo tenant có đủ permission theo từng module trong catalog */
export async function ensureSystemPermissions(db: any, tenant_id: string) {
  const ensuredIds: string[] = [];

  for (const p of SYSTEM_PERMISSIONS) {
    let existing = await db.permission.findFirst({
      where: { action: p.action, resource: p.resource },
      select: { id: true }
    });

    if (!existing) {
      existing = await db.permission.create({
        data: {
          action: p.action,
          resource: p.resource,
          description: p.description,
          tenant_id
        },
        select: { id: true }
      });
    }

    ensuredIds.push(existing.id);
  }

  // Role Admin luôn có đủ quyền catalog (bootstrap / migrate từ admin:settings)
  const adminRole = await db.role.findFirst({
    where: { name: 'Admin' },
    select: { id: true }
  });

  if (adminRole) {
    for (const permission_id of ensuredIds) {
      const link = await db.rolePermission.findFirst({
        where: { role_id: adminRole.id, permission_id },
        select: { id: true }
      });
      if (!link) {
        await db.rolePermission.create({
          data: {
            role_id: adminRole.id,
            permission_id,
            tenant_id
          }
        });
      }
    }
  }
}
