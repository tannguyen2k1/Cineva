import 'dotenv/config';
import { PrismaClient } from '../generated/prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import bcrypt from 'bcryptjs';
import { SYSTEM_PERMISSIONS } from '../server/utils/systemPermissions';
import { getDefaultAdminCredentials } from '../server/utils/defaultAdmin';

const connectionString = process.env.DATABASE_URL || 'postgresql://postgres:password123@localhost:5432/multi_tenant_db?schema=public';
const pool = new Pool({ connectionString });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('Seeding database...');

  const { username: adminUsername, password: adminPassword } = getDefaultAdminCredentials();

  const tenant = await prisma.tenant.upsert({
    where: { domain: 'default' },
    update: {},
    create: {
      name: 'default',
      domain: 'default'
    }
  });

  let role = await prisma.role.findFirst({
    where: { tenant_id: tenant.id, name: 'Admin', deletedAt: null }
  });
  if (!role) {
    role = await prisma.role.create({
      data: {
        tenant_id: tenant.id,
        name: 'Admin',
        description: 'Quản trị viên hệ thống'
      }
    });
  }

  const hashedPassword = await bcrypt.hash(adminPassword, 10);
  let user = await prisma.user.findFirst({
    where: { tenant_id: tenant.id, username: adminUsername, deletedAt: null }
  });
  if (!user) {
    user = await prisma.user.create({
      data: {
        tenant_id: tenant.id,
        username: adminUsername,
        email: null,
        password: hashedPassword,
        fullName: 'Super Admin',
        isActive: true
      }
    });
  } else {
    user = await prisma.user.update({
      where: { id: user.id },
      data: { password: hashedPassword }
    });
  }

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

  for (const p of SYSTEM_PERMISSIONS) {
    const perm = await prisma.permission.upsert({
      where: {
        tenant_id_action_resource: {
          tenant_id: tenant.id,
          action: p.action,
          resource: p.resource
        }
      },
      update: { description: p.description },
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
  console.log(`Workspace: default`);
  console.log(`Username: ${adminUsername}`);
  console.log(`Password: ${adminPassword}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
