import { z } from 'zod';
import { prisma } from '@/lib/server/prisma';
import { badRequest, withPlatformAdmin } from '@/lib/server/route-helpers';
import { formatTenant, tenantSelect } from '@/lib/server/tenants/format';
import { slugify } from '@/lib/server/utils/schedule';

export const runtime = 'nodejs';

const createTenantSchema = z.object({
  name: z.string().min(1).max(120),
  slug: z.string().min(1).max(80).optional(),
});

export async function GET(request: Request) {
  return withPlatformAdmin(request, async () => {
    const tenants = await prisma.tenant.findMany({
      orderBy: { createdAt: 'desc' },
      select: tenantSelect,
    });
    return Response.json(tenants.map(formatTenant));
  });
}

export async function POST(request: Request) {
  return withPlatformAdmin(request, async () => {
    const body = await request.json();
    const parsed = createTenantSchema.safeParse(body);
    if (!parsed.success) {
      return badRequest(parsed.error.flatten());
    }

    let slug = parsed.data.slug ?? slugify(parsed.data.name);
    if (await prisma.tenant.findUnique({ where: { slug } })) {
      slug = `${slug}-${Date.now().toString(36)}`;
    }

    const tenant = await prisma.tenant.create({
      data: {
        name: parsed.data.name,
        slug,
        settings: { create: {} },
      },
      select: tenantSelect,
    });

    return Response.json(formatTenant(tenant), { status: 201 });
  });
}
