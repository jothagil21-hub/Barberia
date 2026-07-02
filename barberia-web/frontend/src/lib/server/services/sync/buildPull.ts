import type { AppointmentStatus } from '@prisma/client';
import { prisma } from '@/lib/server/prisma';
import type { SyncActor } from '@/lib/server/services/sync/staffPermissions';
import { isStaff } from '@/lib/server/services/sync/staffPermissions';
import type { PosInvoiceLine, SyncPullBundle } from '@/lib/server/services/sync/types';

function toIso(d: Date) {
  return d.toISOString();
}

export async function buildPullBundle(
  tenantId: string,
  since?: Date,
  actor?: SyncActor,
): Promise<SyncPullBundle> {
  const sinceFilter = since ? { gt: since } : undefined;
  const staff = actor && isStaff(actor);
  const staffBarberId = staff ? actor.barberId : null;

  if (staff && !staffBarberId) {
    throw new Error('Usuario staff sin barbero asignado');
  }

  const tenant = await prisma.tenant.findUnique({
    where: { id: tenantId },
    include: { settings: true },
  });

  if (!tenant) throw new Error('Tenant no encontrado');

  const settings = tenant.settings ?? {
    displayName: 'Barbería',
    logoUrl: null,
    scheduleStart: '09:00',
    scheduleEnd: '21:00',
    scheduleInterval: 30,
    updatedAt: tenant.updatedAt,
  };

  const [barbers, services, appointments, scheduleBlocks, posInvoices] = await Promise.all([
    prisma.barber.findMany({
      where: {
        tenantId,
        ...(staffBarberId ? { id: staffBarberId } : {}),
        ...(sinceFilter ? { updatedAt: sinceFilter } : {}),
      },
      orderBy: { updatedAt: 'asc' },
    }),
    prisma.service.findMany({
      where: { tenantId, ...(sinceFilter ? { updatedAt: sinceFilter } : {}) },
      orderBy: { updatedAt: 'asc' },
    }),
    prisma.appointment.findMany({
      where: {
        tenantId,
        ...(staffBarberId ? { barberId: staffBarberId } : {}),
        ...(sinceFilter ? { updatedAt: sinceFilter } : {}),
      },
      include: { services: true },
      orderBy: { updatedAt: 'asc' },
    }),
    prisma.scheduleBlock.findMany({
      where: {
        tenantId,
        ...(staffBarberId ? { barberId: staffBarberId } : {}),
        ...(sinceFilter ? { updatedAt: sinceFilter } : {}),
      },
      orderBy: { updatedAt: 'asc' },
    }),
    staff
      ? Promise.resolve([])
      : prisma.posInvoice.findMany({
          where: { tenantId, ...(sinceFilter ? { updatedAt: sinceFilter } : {}) },
          orderBy: { updatedAt: 'asc' },
        }),
  ]);

  const includeSettings =
    !since || settings.updatedAt > since || tenant.updatedAt > since;

  return {
    serverTime: toIso(new Date()),
    settings: includeSettings
      ? {
          shopName: tenant.name,
          displayName: settings.displayName,
          logoUrl: settings.logoUrl,
          scheduleStart: settings.scheduleStart,
          scheduleEnd: settings.scheduleEnd,
          scheduleInterval: settings.scheduleInterval,
          updatedAt: toIso(
            settings.updatedAt > tenant.updatedAt
              ? settings.updatedAt
              : tenant.updatedAt,
          ),
        }
      : {
          shopName: tenant.name,
          displayName: settings.displayName,
          logoUrl: settings.logoUrl,
          scheduleStart: settings.scheduleStart,
          scheduleEnd: settings.scheduleEnd,
          scheduleInterval: settings.scheduleInterval,
          updatedAt: toIso(settings.updatedAt),
        },
    barbers: barbers.map((b) => ({
      id: b.id,
      name: b.name,
      active: b.active,
      updatedAt: toIso(b.updatedAt),
    })),
    services: services.map((s) => ({
      id: s.id,
      name: s.name,
      price: s.price,
      durationMinutes: s.durationMinutes,
      active: s.active,
      updatedAt: toIso(s.updatedAt),
    })),
    appointments: appointments.map((a) => ({
      id: a.id,
      barberId: a.barberId,
      clientName: a.clientName,
      date: a.date,
      time: a.time,
      durationMinutes: a.durationMinutes,
      status: a.status,
      createdAt: toIso(a.createdAt),
      canceledAt: a.canceledAt ? toIso(a.canceledAt) : null,
      updatedAt: toIso(a.updatedAt),
      services: a.services.map((line) => ({
        serviceId: line.serviceId,
        unitPrice: line.unitPrice,
        durationMinutes: line.durationMinutes,
      })),
    })),
    scheduleBlocks: scheduleBlocks.map((b) => ({
      id: b.id,
      barberId: b.barberId,
      date: b.date,
      time: b.time,
      isFullDay: b.isFullDay,
      createdAt: toIso(b.createdAt),
      updatedAt: toIso(b.updatedAt),
    })),
    posInvoices: posInvoices.map((inv) => ({
      id: inv.id,
      appointmentId: inv.appointmentId,
      number: inv.number,
      issuedAt: toIso(inv.issuedAt),
      clientName: inv.clientName,
      barberName: inv.barberName,
      subtotal: inv.subtotal,
      lines: inv.lines as PosInvoiceLine[],
      updatedAt: toIso(inv.updatedAt),
    })),
  };
}

export function parseAppointmentStatus(value: string): AppointmentStatus {
  const allowed = ['scheduled', 'canceled', 'attended', 'no_show'] as const;
  if ((allowed as readonly string[]).includes(value)) {
    return value as AppointmentStatus;
  }
  throw new Error(`Estado de cita inválido: ${value}`);
}
