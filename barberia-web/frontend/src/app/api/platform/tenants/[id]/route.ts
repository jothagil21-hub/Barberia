import { z } from 'zod';
import { prisma } from '@/lib/server/prisma';
import { badRequest, notFound, routeParams, withPlatformAdmin } from '@/lib/server/route-helpers';
import { formatTenant, tenantSelect } from '@/lib/server/tenants/format';

export const runtime = 'nodejs';

const patchTenantSchema = z.object({
  name: z.string().min(1).max(120).optional(),
  active: z.boolean().optional(),
});

type Ctx = { params: Promise<{ id: string }> };

export async function GET(request: Request, context: Ctx) {
  return withPlatformAdmin(request, async () => {
    const { id } = await routeParams(context);
    const tenant = await prisma.tenant.findUnique({
      where: { id },
      select: tenantSelect,
    });
    if (!tenant) return notFound('Barbería no encontrada');
    return Response.json(formatTenant(tenant));
  });
}

export async function PATCH(request: Request, context: Ctx) {
  return withPlatformAdmin(request, async () => {
    const { id } = await routeParams(context);
    const body = await request.json();
    const parsed = patchTenantSchema.safeParse(body);
    if (!parsed.success) {
      return badRequest(parsed.error.flatten());
    }

    const exists = await prisma.tenant.findUnique({ where: { id } });
    if (!exists) return notFound('Barbería no encontrada');

    const tenant = await prisma.tenant.update({
      where: { id },
      data: parsed.data,
      select: tenantSelect,
    });

    return Response.json(formatTenant(tenant));
  });
}
