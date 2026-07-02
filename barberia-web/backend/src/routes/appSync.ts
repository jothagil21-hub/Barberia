import { z } from 'zod';
import type { FastifyInstance } from 'fastify';
import { applySyncChanges } from '../services/sync/applyChanges.js';
import { buildPullBundle } from '../services/sync/buildPull.js';
import { validateServiceDuration } from '../utils/serviceDuration.js';

const serviceLineSchema = z.object({
  serviceId: z.string().uuid(),
  unitPrice: z.number(),
  durationMinutes: z.number().int(),
});

const posInvoiceLineSchema = z.object({
  serviceName: z.string().min(1),
  durationMinutes: z.number().int(),
  unitPrice: z.number(),
  lineTotal: z.number(),
});

const upsertBarberSchema = z.object({
  id: z.string().uuid().optional(),
  clientId: z.string().optional(),
  name: z.string().min(1),
  active: z.boolean(),
  updatedAt: z.string(),
});

const upsertServiceSchema = z.object({
  id: z.string().uuid().optional(),
  clientId: z.string().optional(),
  name: z.string().min(1),
  price: z.number(),
  durationMinutes: z.number().int(),
  active: z.boolean(),
  updatedAt: z.string(),
});

const upsertAppointmentSchema = z.object({
  id: z.string().uuid().optional(),
  clientId: z.string().optional(),
  barberId: z.string().uuid(),
  clientName: z.string().min(1),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  time: z.string().regex(/^\d{2}:\d{2}$/),
  durationMinutes: z.number().int(),
  status: z.enum(['scheduled', 'canceled', 'attended', 'no_show']),
  createdAt: z.string().optional(),
  canceledAt: z.string().nullable().optional(),
  updatedAt: z.string(),
  services: z.array(serviceLineSchema).default([]),
});

const upsertPosInvoiceSchema = z.object({
  id: z.string().uuid().optional(),
  clientId: z.string().optional(),
  appointmentId: z.string().uuid(),
  number: z.number().int(),
  issuedAt: z.string(),
  clientName: z.string().min(1),
  barberName: z.string().nullable().optional(),
  subtotal: z.number(),
  lines: z.array(posInvoiceLineSchema),
  updatedAt: z.string(),
});

const upsertBlockSchema = z.object({
  id: z.string().uuid().optional(),
  clientId: z.string().optional(),
  barberId: z.string().uuid(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  time: z.string().regex(/^\d{2}:\d{2}$/).nullable().optional(),
  isFullDay: z.boolean(),
  createdAt: z.string().optional(),
  updatedAt: z.string(),
});

const syncPostSchema = z.object({
  since: z.string().optional(),
  changes: z.object({
    barbers: z.array(upsertBarberSchema).optional(),
    services: z.array(upsertServiceSchema).optional(),
    appointments: z.array(upsertAppointmentSchema).optional(),
    scheduleBlocks: z.array(upsertBlockSchema).optional(),
    posInvoices: z.array(upsertPosInvoiceSchema).optional(),
    settings: z
      .object({
        shopName: z.string().min(1).optional(),
        displayName: z.string().min(1).optional(),
        scheduleStart: z.string().regex(/^\d{2}:\d{2}$/).optional(),
        scheduleEnd: z.string().regex(/^\d{2}:\d{2}$/).optional(),
        scheduleInterval: z.number().int().optional(),
        updatedAt: z.string().optional(),
      })
      .optional(),
  }),
});

function parseSince(value?: string) {
  if (!value) return undefined;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return undefined;
  return d;
}

export async function appSyncRoutes(app: FastifyInstance) {
  app.addHook('onRequest', app.authenticateTenantUser);

  app.get<{ Querystring: { since?: string } }>('/api/app/sync', async (request, reply) => {
    const tenantId = request.appUser!.tenantId;
    const since = parseSince(request.query.since);

    try {
      return await buildPullBundle(tenantId, since);
    } catch {
      return reply.status(404).send({ error: 'Barbería no encontrada' });
    }
  });

  app.post('/api/app/sync', async (request, reply) => {
    const parsed = syncPostSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: parsed.error.flatten() });
    }

    for (const service of parsed.data.changes.services ?? []) {
      try {
        validateServiceDuration(service.durationMinutes);
      } catch (e) {
        return reply.status(400).send({
          error: e instanceof Error ? e.message : 'Duración de servicio inválida',
        });
      }
    }

    const tenantId = request.appUser!.tenantId;
    const role = request.appUser!.role;
    const since = parseSince(parsed.data.since);

    try {
      return await applySyncChanges(tenantId, role, parsed.data.changes, since);
    } catch (e) {
      const message = e instanceof Error ? e.message : 'Error de sync';
      return reply.status(400).send({ error: message });
    }
  });
}
