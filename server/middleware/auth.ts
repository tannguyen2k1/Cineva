import { jwtVerify } from 'jose';

const JWT_SECRET = new TextEncoder().encode(process.env.JWT_SECRET || 'super-secret-key-for-local-dev-only');

export default defineEventHandler(async (event) => {
  // Chỉ apply auth cho các route /api/ (trừ các route public như login/register)
  const pathname = getRequestURL(event).pathname;
  if (!pathname.startsWith('/api/')) return;
  if (pathname.startsWith('/api/auth/login') || pathname.startsWith('/api/auth/register')) return;

  const authHeader = getHeader(event, 'authorization');
  const tenantIdHeader = getHeader(event, 'x-tenant-id');

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized: Missing or invalid token' });
  }

  const token = authHeader.split(' ')[1];
  
  if (!token) {
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized: Missing token' });
  }

  try {
    const { payload } = await jwtVerify(token, JWT_SECRET);
    
    // Lưu thông tin user vào context để các API router dùng
    event.context.user = payload;
    
    // Nếu có truyền x-tenant-id, lưu vào context để Prisma query an toàn. Nếu không, lấy từ payload của token
    event.context.tenant_id = tenantIdHeader || payload.tenant_id;

  } catch (error) {
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized: Token expired or invalid' });
  }
});
