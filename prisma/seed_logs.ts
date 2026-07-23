import { prisma } from '../server/utils/prisma';

async function main() {
  const tenant = await prisma.tenant.findFirst();
  if (!tenant) {
    console.error('No tenant found in the database.');
    return;
  }
  const user = await prisma.user.findFirst({ where: { tenant_id: tenant.id } });
  
  const actions = ['LOGIN', 'CREATE_USER', 'UPDATE_ROLE', 'DELETE_DATA', 'VIEW_DASHBOARD', 'EXPORT_REPORT'];
  const resources = ['Auth', 'User', 'Role', 'Tenant', 'System', 'Report'];

  console.log('Clearing existing logs...');
  await prisma.systemLog.deleteMany();

  console.log(`Seeding 124 logs for tenant: ${tenant.name}...`);
  
  const data = [];
  const now = new Date();
  
  for (let i = 1; i <= 124; i++) {
    const action = actions[Math.floor(Math.random() * actions.length)] as string;
    const resource = resources[Math.floor(Math.random() * resources.length)] as string;
    const date = new Date(now.getTime() - i * 15 * 60000); // Back in time 15 mins per log
    
    data.push({
      tenant_id: tenant.id,
      user_id: user?.id || null,
      action,
      resource,
      details: JSON.stringify({ note: `Log entry #${i}`, status: 'success', ip: '192.168.1.' + (i % 255) }),
      createdAt: date
    });
  }
  
  await prisma.systemLog.createMany({
    data
  });
  
  console.log('Seeding 124 logs finished successfully!');
}

main().catch(e => {
  console.error(e);
  process.exit(1);
}).finally(async () => {
  await prisma.$disconnect();
});
