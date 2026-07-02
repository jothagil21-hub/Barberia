import { z } from 'zod';
import { prisma } from '@/lib/server/prisma';
import { badRequest, notFound, routeParams, withPlatformAdmin } from '@/lib/server/route-helpers';
import { STATUS_LABELS } from '@/lib/server/tenants/format';

export const runtime = 'nodejs';

const dateQuerySchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Formato de fecha: YYYY-MM-DD'),
});

type Ctx = { params: Promise<{ id: string }> };

export async function GET(request: Request, context: Ctx) {
  return withPlatformAdmin(request, async () => {
    const { id } = await routeParams(context);
    const url = new URL(request.url);
    const parsed = dateQuerySchema.safeParse({ date: url.searchParams.get('date') ?? undefined });
    if (!parsed.success) {
      return badRequest(
        parsed.error.flatten().fieldErrors.date?.[0] ?? 'Parámetro date requerido (YYYY-MM-DD)',
      );
    }

    const tenant = await prisma.tenant.findUnique({ where: { id } });
    if (!tenant) return notFound('Barbería no encontrada');

    const { date } = parsed.data;

    const barbers = await prisma.barber.findMany({
      where: { tenantId: tenant.id, active: true },
      orderBy: { name: 'asc' },
    });

    const appointments = await prisma.appointment.findMany({
      where: { tenantId: tenant.id, date },
      include: {
        services: {
          include: { service: { select: { name: true } } },
        },
      },
      orderBy: [{ barberId: 'asc' }, { time: 'asc' }],
    });

    const byBarber = new Map<string, typeof appointments>();
    for (const apt of appointments) {
      const list = byBarber.get(apt.barberId) ?? [];
      list.push(apt);
      byBarber.set(apt.barberId, list);
    }

    return Response.json({
      date,
      tenantName: tenant.name,
      barbers: barbers.map((barber) => ({
        id: barber.id,
        name: barber.name,
        active: barber.active,
        appointments: (byBarber.get(barber.id) ?? []).map((apt) => {
          const services = apt.services.map((line) => ({
            name: line.service.name,
            unitPrice: line.unitPrice,
            durationMinutes: line.durationMinutes,
          }));
          const totalPrice = services.reduce((sum, s) => sum + s.unitPrice, 0);
          return {
            id: apt.id,
            clientName: apt.clientName,
            time: apt.time,
            durationMinutes: apt.durationMinutes,
            status: apt.status,
            statusLabel: STATUS_LABELS[apt.status] ?? apt.status,
            services,
            totalPrice,
          };
        }),
      })),
    });
  });
}
