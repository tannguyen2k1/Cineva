/** Convert crop canvas to square JPEG avatar file. */
export async function canvasToAvatarFile(
  sourceCanvas: HTMLCanvasElement,
  size = 512,
  quality = 0.92
): Promise<File> {
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;

  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Canvas not supported');

  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(sourceCanvas, 0, 0, size, size);

  const blob = await new Promise<Blob>((resolve, reject) => {
    canvas.toBlob(
      (result) => (result ? resolve(result) : reject(new Error('Không thể xử lý ảnh'))),
      'image/jpeg',
      quality
    );
  });

  return new File([blob], `avatar-${Date.now()}.jpg`, { type: 'image/jpeg' });
}

export function withCacheBust(url: string) {
  const clean = url.split('?')[0];
  return `${clean}?t=${Date.now()}`;
}
