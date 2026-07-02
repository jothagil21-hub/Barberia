import { mkdir, writeFile, unlink, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { prisma } from '@/lib/server/prisma';

const ALLOWED_MIME = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];

export function getUploadDir(): string {
  return process.env.UPLOAD_DIR ?? join(process.cwd(), 'uploads');
}

export async function saveTenantLogo(tenantId: string, file: File) {
  if (!ALLOWED_MIME.includes(file.type)) {
    throw new Error('Tipo de imagen no permitido');
  }

  const ext = file.type.split('/')[1] ?? 'png';
  const filename = `${tenantId}.${ext}`;
  const uploadDir = getUploadDir();
  await mkdir(uploadDir, { recursive: true });

  const filepath = join(uploadDir, filename);
  const buffer = Buffer.from(await file.arrayBuffer());
  await writeFile(filepath, buffer);

  const version = Date.now();
  const logoUrl = `/uploads/${filename}?v=${version}`;
  const now = new Date();
  return prisma.tenantSettings.upsert({
    where: { tenantId },
    create: { tenantId, logoUrl, updatedAt: now },
    update: { logoUrl, updatedAt: now },
  });
}

export async function readUploadedFile(filename: string): Promise<{ buffer: Buffer; mime: string } | null> {
  const safeName = filename.split('?')[0].replace(/[^a-zA-Z0-9._-]/g, '');
  if (!safeName) return null;

  const filepath = join(getUploadDir(), safeName);
  try {
    const buffer = await readFile(filepath);
    const ext = safeName.split('.').pop()?.toLowerCase();
    const mime =
      ext === 'png'
        ? 'image/png'
        : ext === 'webp'
          ? 'image/webp'
          : ext === 'gif'
            ? 'image/gif'
            : 'image/jpeg';
    return { buffer, mime };
  } catch {
    return null;
  }
}

export async function deleteTenantLogo(tenantId: string) {
  const settings = await prisma.tenantSettings.findUnique({ where: { tenantId } });
  if (settings?.logoUrl) {
    const filename = settings.logoUrl.replace(/^\/uploads\//, '').split('?')[0];
    const filepath = join(getUploadDir(), filename);
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
