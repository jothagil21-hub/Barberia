import { z } from 'zod';
import type { FastifyInstance } from 'fastify';
import { prisma } from '../lib/prisma.js';

const dateQuerySchema = z.object({
  date: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'Formato de fecha: YYYY-MM-DD')
    .optional(),
});

export async function tenantInvoicesRoutes(app: FastifyInstance) {
  app.addHook('onRequest', app.authenticatePlatform);

  app.get<{ Params: { id: string }; Querystring: { date?: string } }>(
    '/api/platform/tenants/:id/invoices',
    async (request, reply) => {
      const parsed = dateQuerySchema.safeParse(request.query);
      if (!parsed.success) {
        return reply.status(400).send({ error: 'Parámetro date inválido (YYYY-MM-DD)' });
      }

      const tenant = await prisma.tenant.findUnique({ where: { id: request.params.id } });
      if (!tenant) {
        return reply.status(404).send({ error: 'Barbería no encontrada' });
      }

      const { date } = parsed.data;
      const invoices = await prisma.posInvoice.findMany({
        where: {
          tenantId: tenant.id,
          ...(date
            ? {
                appointment: { date },
              }
            : {}),
        },
        include: {
          appointment: { select: { id: true, date: true, time: true } },
        },
        orderBy: [{ issuedAt: 'desc' }],
      });

      return {
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
      };
    },
  );

  app.get<{ Params: { id: string; invoiceId: string } }>(
    '/api/platform/tenants/:id/invoices/:invoiceId',
    async (request, reply) => {
      const tenant = await prisma.tenant.findUnique({ where: { id: request.params.id } });
      if (!tenant) {
        return reply.status(404).send({ error: 'Barbería no encontrada' });
      }

      const invoice = await prisma.posInvoice.findFirst({
        where: { id: request.params.invoiceId, tenantId: tenant.id },
        include: {
          appointment: { select: { id: true, date: true, time: true, status: true } },
        },
      });

      if (!invoice) {
        return reply.status(404).send({ error: 'Comprobante no encontrado' });
      }

      return {
        id: invoice.id,
        appointmentId: invoice.appointmentId,
        number: invoice.number,
        issuedAt: invoice.issuedAt.toISOString(),
        clientName: invoice.clientName,
        barberName: invoice.barberName,
        subtotal: invoice.subtotal,
        lines: invoice.lines,
        appointment: invoice.appointment,
      };
    },
  );

  app.get<{ Params: { id: string; appointmentId: string } }>(
    '/api/platform/tenants/:id/invoices/by-appointment/:appointmentId',
    async (request, reply) => {
      const tenant = await prisma.tenant.findUnique({ where: { id: request.params.id } });
      if (!tenant) {
        return reply.status(404).send({ error: 'Barbería no encontrada' });
      }

      const invoice = await prisma.posInvoice.findFirst({
        where: {
          tenantId: tenant.id,
          appointmentId: request.params.appointmentId,
        },
      });

      if (!invoice) {
        return reply.status(404).send({ error: 'Comprobante no encontrado' });
      }

      return {
        id: invoice.id,
        appointmentId: invoice.appointmentId,
        number: invoice.number,
        issuedAt: invoice.issuedAt.toISOString(),
        clientName: invoice.clientName,
        barberName: invoice.barberName,
        subtotal: invoice.subtotal,
        lines: invoice.lines,
      };
    },
  );
}
