import { z } from 'zod';
import { prisma } from '@/lib/server/prisma';
import { badRequest, notFound, routeParams, withPlatformAdmin } from '@/lib/server/route-helpers';

export const runtime = 'nodejs';

const dateQuerySchema = z.object({
  date: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'Formato de fecha: YYYY-MM-DD')
    .optional(),
});

type Ctx = { params: Promise<{ id: string }> };

export async function GET(request: Request, context: Ctx) {
  return withPlatformAdmin(request, async () => {
    const { id } = await routeParams(context);
    const url = new URL(request.url);
    const dateParam = url.searchParams.get('date') ?? undefined;
    const parsed = dateQuerySchema.safeParse({ date: dateParam });
    if (!parsed.success) {
      return badRequest('Parámetro date inválido (YYYY-MM-DD)');
    }

    const tenant = await prisma.tenant.findUnique({ where: { id } });
    if (!tenant) return notFound('Barbería no encontrada');

    const { date } = parsed.data;
    const invoices = await prisma.posInvoice.findMany({
      where: {
        tenantId: tenant.id,
        ...(date ? { appointment: { date } } : {}),
      },
      include: {
        appointment: { select: { id: true, date: true, time: true } },
      },
      orderBy: [{ issuedAt: 'desc' }],
    });

    return Response.json({
      tenantName: tenant.name,
      invoices: invoices.map((inv) => ({
        id: inv.id,
        appointmentId: inv.appointmentId,
        number: inv.number,
        issuedAt: inv.issuedAt.toISOString(),
        clientName: inv.clientName,
        barberName: inv.barberName,
        subtotal: inv.subtotal,
        appointmentDate: inv.appointment.date,
        appointmentTime: inv.appointment.time,
      })),
    });
  });
}
