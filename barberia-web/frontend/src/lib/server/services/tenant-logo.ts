import { del, put } from '@vercel/blob';
import { mkdir, writeFile, unlink, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { prisma } from '@/lib/server/prisma';

const ALLOWED_MIME = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];

export function getUploadDir(): string {
  return process.env.UPLOAD_DIR ?? join(process.cwd(), 'uploads');
}

function useBlobStorage(): boolean {
  return Boolean(
    process.env.BLOB_READ_WRITE_TOKEN?.trim() || process.env.BLOB_STORE_ID?.trim(),
  );
}

function isBlobUrl(logoUrl: string): boolean {
  return logoUrl.startsWith('http') && logoUrl.includes('blob.vercel-storage.com');
}

function stripQuery(logoUrl: string): string {
  return logoUrl.split('?')[0];
}

async function deleteStoredLogo(logoUrl: string): Promise<void> {
  if (isBlobUrl(logoUrl)) {
    try {
      await del(stripQuery(logoUrl));
    } catch {
      /* blob ya eliminado */
    }
    return;
  }

  if (logoUrl.startsWith('/uploads/')) {
    const filename = logoUrl.replace(/^\/uploads\//, '').split('?')[0];
    const filepath = join(getUploadDir(), filename);
    try {
      await unlink(filepath);
    } catch {
      /* archivo ya eliminado */
    }
  }
}

async function saveToBlob(tenantId: string, ext: string, buffer: Buffer, previousLogoUrl: string | null) {
  if (previousLogoUrl) {
    await deleteStoredLogo(previousLogoUrl);
  }

  const blob = await put(`logos/${tenantId}.${ext}`, buffer, {
    access: 'public',
    addRandomSuffix: false,
  });

  const version = Date.now();
  return `${blob.url}?v=${version}`;
}

async function saveToFilesystem(tenantId: string, ext: string, buffer: Buffer) {
  const filename = `${tenantId}.${ext}`;
  const uploadDir = getUploadDir();
  await mkdir(uploadDir, { recursive: true });

  const filepath = join(uploadDir, filename);
  await writeFile(filepath, buffer);

  const version = Date.now();
  return `/uploads/${filename}?v=${version}`;
}

export async function saveTenantLogo(tenantId: string, file: File) {
  if (!ALLOWED_MIME.includes(file.type)) {
    throw new Error('Tipo de imagen no permitido');
  }

  const ext = file.type.split('/')[1] ?? 'png';
  const buffer = Buffer.from(await file.arrayBuffer());

  const existing = await prisma.tenantSettings.findUnique({ where: { tenantId } });
  const previousLogoUrl = existing?.logoUrl ?? null;

  const logoUrl = useBlobStorage()
    ? await saveToBlob(tenantId, ext, buffer, previousLogoUrl)
    : await saveToFilesystem(tenantId, ext, buffer);

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
    await deleteStoredLogo(settings.logoUrl);
  }

  const now = new Date();
  return prisma.tenantSettings.upsert({
    where: { tenantId },
    create: { tenantId, logoUrl: null, updatedAt: now },
    update: { logoUrl: null, updatedAt: now },
  });
}
