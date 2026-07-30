import { readMultipartFormData } from 'h3';
import { promises as fs } from 'fs';
import path from 'path';
import { prisma } from '../../utils/prisma';
import crypto from 'crypto';

defineRouteMeta({
  openAPI: {
    tags: ['Users'],
    description: 'Upload avatar image for the signed-in user.',
    security: [{ bearerAuth: [] }]
  }
})

export default defineEventHandler(async (event) => {
  try {
    const userId = event.context.user?.userId;
    if (!userId) {
      throw createError({ statusCode: 401, statusMessage: 'Unauthorized' });
    }

    const formData = await readMultipartFormData(event);
    if (!formData) {
      throw createError({ statusCode: 400, statusMessage: 'Invalid form data' });
    }

    // Find the file field
    const fileField = formData.find(field => field.name === 'file');
    if (!fileField || !fileField.filename || !fileField.data) {
      throw createError({ statusCode: 400, statusMessage: 'No file uploaded' });
    }

    // 1. Kiểm tra kích thước (Giới hạn 5MB = 5 * 1024 * 1024 bytes)
    const MAX_SIZE = 5 * 1024 * 1024;
    if (fileField.data.length > MAX_SIZE) {
      throw createError({ statusCode: 400, statusMessage: 'Kích thước file không được vượt quá 5MB' });
    }

    // 2. Kiểm tra Mime Type an toàn (Tránh file thực thi bị đổi đuôi)
    const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    if (!fileField.type || !allowedMimeTypes.includes(fileField.type)) {
      throw createError({ statusCode: 400, statusMessage: 'Chỉ chấp nhận file định dạng hình ảnh hợp lệ (JPG, PNG, GIF, WEBP)' });
    }

    // 3. Lấy đuôi file và kiểm tra an toàn
    const ext = path.extname(fileField.filename).toLowerCase();
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    if (!allowedExtensions.includes(ext)) {
      throw createError({ statusCode: 400, statusMessage: 'Đuôi file không được phép tải lên' });
    }

    // Create upload dir if not exists
    const uploadDir = path.join(process.cwd(), 'public', 'uploads', 'avatars');
    await fs.mkdir(uploadDir, { recursive: true });

    // Generate unique filename
    const fileName = `${crypto.randomUUID()}${ext}`;
    const filePath = path.join(uploadDir, fileName);

    // Write file to filesystem
    await fs.writeFile(filePath, fileField.data);

    // Update user avatar URL in DB
    const avatarUrl = `/uploads/avatars/${fileName}`;
    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: { avatar: avatarUrl },
      select: { id: true, avatar: true }
    });

    return {
      success: true,
      data: { avatar: updatedUser.avatar }
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
