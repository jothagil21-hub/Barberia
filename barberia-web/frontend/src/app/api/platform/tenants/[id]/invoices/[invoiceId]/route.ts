import { prisma } from '@/lib/server/prisma';
import { notFound, routeParams, withPlatformAdmin } from '@/lib/server/route-helpers';

export const runtime = 'nodejs';

type Ctx = { params: Promise<{ id: string; invoiceId: string }> };

export async function GET(request: Request, context: Ctx) {
  return withPlatformAdmin(request, async () => {
    const { id, invoiceId } = await routeParams(context);
    const tenant = await prisma.tenant.findUnique({ where: { id } });
    if (!tenant) return notFound('Barbería no encontrada');

    const invoice = await prisma.posInvoice.findFirst({
      where: { id: invoiceId, tenantId: tenant.id },
      include: {
        appointment: { select: { id: true, date: true, time: true, status: true } },
      },
    });

    if (!invoice) return notFound('Comprobante no encontrado');

    return Response.json({
      id: invoice.id,
      appointmentId: invoice.appointmentId,
      number: invoice.number,
      issuedAt: invoice.issuedAt.toISOString(),
      clientName: invoice.clientName,
      barberName: invoice.barberName,
      subtotal: invoice.subtotal,
      lines: invoice.lines,
      appointment: invoice.appointment,
    });
  });
}
