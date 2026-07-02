import { prisma } from '@/lib/server/prisma';
import { notFound, routeParams, withPlatformAdmin } from '@/lib/server/route-helpers';

export const runtime = 'nodejs';

type Ctx = { params: Promise<{ id: string }> };

export async function GET(request: Request, context: Ctx) {
  return withPlatformAdmin(request, async () => {
    const { id } = await routeParams(context);
    const tenant = await prisma.tenant.findUnique({ where: { id } });
    if (!tenant) return notFound('Barbería no encontrada');

    const barbers = await prisma.barber.findMany({
      where: { tenantId: tenant.id },
      orderBy: [{ active: 'desc' }, { name: 'asc' }],
    });

    return Response.json({
      barbers: barbers.map((b) => ({
        id: b.id,
        name: b.name,
        active: b.active,
        updatedAt: b.updatedAt.toISOString(),
      })),
    });
  });
}
