import { z } from 'zod';
import { applySyncChanges } from '@/lib/server/services/sync/applyChanges';
import { buildPullBundle } from '@/lib/server/services/sync/buildPull';
import { loadSyncActor } from '@/lib/server/services/sync/staffPermissions';
import { validateServiceDuration } from '@/lib/server/utils/serviceDuration';
import { badRequest, notFound, withTenantUser } from '@/lib/server/route-helpers';

export const runtime = 'nodejs';
export const maxDuration = 60;

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

function parseSince(value?: string | null) {
  if (!value) return undefined;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return undefined;
  return d;
}

export async function GET(request: Request) {
  return withTenantUser(request, async (_request, user) => {
    const url = new URL(request.url);
    const since = parseSince(url.searchParams.get('since'));
    const actor = await loadSyncActor(user.sub);
    if (!actor) {
      return Response.json({ error: 'Sesión inválida' }, { status: 401 });
    }

    try {
      const bundle = await buildPullBundle(user.tenantId, since, actor);
      return Response.json(bundle);
    } catch (e) {
      const message = e instanceof Error ? e.message : 'Barbería no encontrada';
      if (message.includes('sin barbero asignado')) {
        return badRequest(message);
      }
      return notFound('Barbería no encontrada');
    }
  });
}

export async function POST(request: Request) {
  return withTenantUser(request, async (req, user) => {
    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return badRequest('Cuerpo JSON inválido');
    }

    const parsed = syncPostSchema.safeParse(body);
    if (!parsed.success) {
      return badRequest(parsed.error.flatten());
    }

    for (const service of parsed.data.changes.services ?? []) {
      try {
        validateServiceDuration(service.durationMinutes);
      } catch (e) {
        return badRequest(
          e instanceof Error ? e.message : 'Duración de servicio inválida',
        );
      }
    }

    const since = parseSince(parsed.data.since);
    const actor = await loadSyncActor(user.sub);
    if (!actor) {
      return Response.json({ error: 'Sesión inválida' }, { status: 401 });
    }

    try {
      const result = await applySyncChanges(
        user.tenantId,
        actor,
        parsed.data.changes,
        since,
      );
      return Response.json(result);
    } catch (e) {
      const message = e instanceof Error ? e.message : 'Error de sync';
      return badRequest(message);
    }
  });
}
