import { prisma } from '../../utils/prisma';
import bcrypt from 'bcryptjs';

defineRouteMeta({
  openAPI: {
    tags: ['Users'],
    description: 'Update the signed-in user profile.',
    security: [{ bearerAuth: [] }]
  }
})

export default defineEventHandler(async (event) => {
  const userId = event.context.user?.userId;
  if (!userId) {
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized' });
  }

  const body = await readBody(event);
  const { fullName, email, password } = body;

  const dataToUpdate: any = {};
  if (fullName !== undefined) dataToUpdate.fullName = fullName;
  if (email !== undefined) dataToUpdate.email = email;
  
  if (password && password.trim() !== '') {
    dataToUpdate.password = await bcrypt.hash(password, 10);
  }

  try {
    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: dataToUpdate,
      select: {
        id: true,
        username: true,
        email: true,
        fullName: true,
        avatar: true,
        isActive: true,
        tenant_id: true,
      }
    });

    return {
      success: true,
      data: updatedUser
    };
  } catch (error) {
    console.error('Update profile error:', error);
    throw createError({ statusCode: 500, statusMessage: 'Lỗi khi cập nhật hồ sơ' });
  }
});
