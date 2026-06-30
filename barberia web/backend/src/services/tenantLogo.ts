import { createWriteStream } from 'node:fs';
import { mkdir, unlink } from 'node:fs/promises';
import { join } from 'node:path';
import type { MultipartFile } from '@fastify/multipart';
import { prisma } from '../lib/prisma.js';

const ALLOWED_MIME = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];

export async function saveTenantLogo(tenantId: string, file: MultipartFile) {
  if (!ALLOWED_MIME.includes(file.mimetype)) {
    throw new Error('Tipo de imagen no permitido');
  }

  const ext = file.mimetype.split('/')[1] ?? 'png';
  const filename = `${tenantId}.${ext}`;
  const uploadDir = process.env.UPLOAD_DIR ?? './uploads';
  await mkdir(uploadDir, { recursive: true });

  const filepath = join(process.cwd(), uploadDir, filename);
  await new Promise<void>((resolve, reject) => {
    const stream = createWriteStream(filepath);
    file.file.pipe(stream);
    stream.on('finish', resolve);
    stream.on('error', reject);
  });

  const version = Date.now();
  const logoUrl = `/uploads/${filename}?v=${version}`;
  const now = new Date();
  return prisma.tenantSettings.upsert({
    where: { tenantId },
    create: { tenantId, logoUrl, updatedAt: now },
    update: { logoUrl, updatedAt: now },
  });
}

export async function deleteTenantLogo(tenantId: string) {
  const settings = await prisma.tenantSettings.findUnique({ where: { tenantId } });
  if (settings?.logoUrl) {
    const uploadDir = process.env.UPLOAD_DIR ?? './uploads';
    const filename = settings.logoUrl.replace(/^\/uploads\//, '').split('?')[0];
    const filepath = join(process.cwd(), uploadDir, filename);
    try {
      await unlink(filepath);
    } catch {
      /* archivo ya eliminado */
    }
  }

  const now = new Date();
  return prisma.tenantSettings.upsert({
    where: { tenantId },
    create: { tenantId, logoUrl: null, updatedAt: now },
    update: { logoUrl: null, updatedAt: now },
  });
}
