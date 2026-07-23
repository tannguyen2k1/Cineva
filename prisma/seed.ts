import { PrismaClient } from '../generated/prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import bcrypt from 'bcryptjs';

const connectionString = process.env.DATABASE_URL || 'postgresql://postgres:password123@localhost:5432/multi_tenant_db?schema=public';
const pool = new Pool({ connectionString });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('Seeding database...');

  // 1. Tạo Tenant mặc định
  const tenant = await prisma.tenant.upsert({
    where: { domain: 'default' },
    update: {},
    create: {
      name: 'default',
      domain: 'default'
    }
  });

  // 2. Tạo Role Admin cho Tenant
  const role = await prisma.role.upsert({
    where: { 
      tenant_id_name: { tenant_id: tenant.id, name: 'Admin' } 
    },
    update: {},
    create: {
      tenant_id: tenant.id,
      name: 'Admin',
      description: 'Quản trị viên hệ thống'
    }
  });

  // 3. Tạo User mặc định
  const hashedPassword = await bcrypt.hash('123456', 10);
  const user = await prisma.user.upsert({
    where: { 
      tenant_id_username: { tenant_id: tenant.id, username: 'admin' } 
    },
    update: {},
    create: {
      tenant_id: tenant.id,
      username: 'admin',
      email: null,
      password: hashedPassword,
      fullName: 'Super Admin',
      isActive: true
    }
  });

  // 4. Gán Role cho User
  await prisma.userRole.upsert({
    where: {
      user_id_role_id: { user_id: user.id, role_id: role.id }
    },
    update: {},
    create: {
      tenant_id: tenant.id,
      user_id: user.id,
      role_id: role.id
    }
  });

  // 5. Gán Quyền cơ bản (để test)
  const permissions = [
    { action: 'read', resource: 'users', description: 'Xem danh sách user' },
    { action: 'admin', resource: 'settings', description: 'Cài đặt hệ thống' }
  ];

  for (const p of permissions) {
    const perm = await prisma.permission.upsert({
      where: {
        tenant_id_action_resource: { tenant_id: tenant.id, action: p.action, resource: p.resource }
      },
      update: {},
      create: {
        tenant_id: tenant.id,
        action: p.action,
        resource: p.resource,
        description: p.description
      }
    });

    await prisma.rolePermission.upsert({
      where: {
        role_id_permission_id: { role_id: role.id, permission_id: perm.id }
      },
      update: {},
      create: {
        tenant_id: tenant.id,
        role_id: role.id,
        permission_id: perm.id
      }
    });
  }

  console.log('Seeding completed!');
  console.log('--- DEFAULT ACCOUNT ---');
  console.log('Tenant ID: workspace1');
  console.log('Email: admin@gmail.com');
  console.log('Password: 123456');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
