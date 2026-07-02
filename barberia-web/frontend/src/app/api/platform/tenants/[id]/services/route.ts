import { prisma } from '@/lib/server/prisma';
import { notFound, routeParams, withPlatformAdmin } from '@/lib/server/route-helpers';

export const runtime = 'nodejs';

type Ctx = { params: Promise<{ id: string }> };

export async function GET(request: Request, context: Ctx) {
  return withPlatformAdmin(request, async () => {
    const { id } = await routeParams(context);
    const tenant = await prisma.tenant.findUnique({
      where: { id },
      include: { settings: true },
    });
    if (!tenant) return notFound('Barbería no encontrada');

    const services = await prisma.service.findMany({
      where: { tenantId: tenant.id },
      orderBy: [{ active: 'desc' }, { name: 'asc' }],
    });

    return Response.json({
      tenantName: tenant.settings?.displayName ?? tenant.name,
      services: services.map((s) => ({
        id: s.id,
        name: s.name,
        price: s.price,
        durationMinutes: s.durationMinutes,
        active: s.active,
        updatedAt: s.updatedAt.toISOString(),
      })),
    });
  });
}
