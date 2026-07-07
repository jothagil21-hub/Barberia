import type { AppointmentSource, AppointmentStatus } from '@prisma/client';
import { prisma } from '@/lib/server/prisma';
import { occupiedFromAppointments, buildBookingGrid } from '@/lib/server/utils/timeSlotGenerator';
import { expandOccupiedSlots } from '@/lib/server/utils/appointmentSlots';
import { validateServiceDuration } from '@/lib/server/utils/serviceDuration';
import { notifyNewPendingRequest } from '@/lib/server/services/notifications/fcm';
import { getBookingLocalReference } from '@/lib/server/utils/bookingTimezone';

const PENDING_HOLD_HOURS = 24;
const OCCUPYING_STATUSES: AppointmentStatus[] = ['scheduled', 'pending'];

export async function loadTenantBySlug(slug: string) {
  return prisma.tenant.findFirst({
    where: { slug, active: true },
    include: { settings: true },
  });
}

export async function getPublicBookingCatalog(slug: string) {
  const tenant = await loadTenantBySlug(slug);
  if (!tenant) return null;
  if (tenant.settings && !tenant.settings.onlineBookingEnabled) {
    return { tenant, disabled: true as const };
  }

  const [barbers, services] = await Promise.all([
    prisma.barber.findMany({
      where: { tenantId: tenant.id, active: true },
      orderBy: { name: 'asc' },
      select: { id: true, name: true },
    }),
    prisma.service.findMany({
      where: { tenantId: tenant.id, active: true },
      orderBy: { name: 'asc' },
      select: { id: true, name: true, price: true, durationMinutes: true },
    }),
  ]);

  const settings = tenant.settings ?? {
    displayName: tenant.name,
    logoUrl: null,
    scheduleStart: '09:00',
    scheduleEnd: '21:00',
    scheduleInterval: 30,
    onlineBookingEnabled: true,
  };

  return {
    tenant,
    disabled: false as const,
    displayName: settings.displayName,
    logoUrl: settings.logoUrl,
    scheduleStart: settings.scheduleStart,
    scheduleEnd: settings.scheduleEnd,
    scheduleInterval: settings.scheduleInterval,
    barbers,
    services,
  };
}

async function getBlockedSlots(tenantId: string, barberId: string, date: string) {
  const blocks = await prisma.scheduleBlock.findMany({
    where: { tenantId, barberId, date },
  });
  const blocked = new Set<string>();
  for (const block of blocks) {
    if (block.isFullDay) {
      return { fullDay: true as const, slots: [] as string[] };
    }
    if (block.time) blocked.add(block.time);
  }
  return { fullDay: false as const, slots: [...blocked] };
}

export async function getAvailableSlots(params: {
  slug: string;
  barberId: string;
  date: string;
  serviceIds: string[];
  localReference?: { date: string; minutesSinceMidnight: number };
}) {
  const catalog = await getPublicBookingCatalog(params.slug);
  if (!catalog) return { error: 'not_found' as const };
  if (catalog.disabled) return { error: 'disabled' as const };

  const { tenant } = catalog;
  const barber = await prisma.barber.findFirst({
    where: { id: params.barberId, tenantId: tenant.id, active: true },
  });
  if (!barber) return { error: 'invalid_barber' as const };

  if (!/^\d{4}-\d{2}-\d{2}$/.test(params.date)) {
    return { error: 'invalid_date' as const };
  }

  const services = await prisma.service.findMany({
    where: {
      tenantId: tenant.id,
      active: true,
      id: { in: params.serviceIds },
    },
  });
  if (services.length === 0 || services.length !== params.serviceIds.length) {
    return { error: 'invalid_services' as const };
  }

  const durationMinutes = services.reduce((sum, s) => sum + s.durationMinutes, 0);
  try {
    validateServiceDuration(durationMinutes);
  } catch (e) {
    return {
      error: 'invalid_duration' as const,
      message: e instanceof Error ? e.message : 'Duración inválida',
    };
  }

  const blocked = await getBlockedSlots(tenant.id, barber.id, params.date);
  if (blocked.fullDay) {
    return { slots: [] as string[], durationMinutes };
  }

  const occupying = await prisma.appointment.findMany({
    where: {
      tenantId: tenant.id,
      barberId: barber.id,
      date: params.date,
      status: { in: OCCUPYING_STATUSES },
    },
    select: { time: true, durationMinutes: true },
  });

  const occupiedSlots = occupiedFromAppointments(occupying);
  const settings = tenant.settings ?? {
    scheduleStart: '09:00',
    scheduleEnd: '21:00',
    scheduleInterval: 30,
  };

  const grid = buildBookingGrid({
    config: {
      scheduleStart: settings.scheduleStart,
      scheduleEnd: settings.scheduleEnd,
      scheduleInterval: settings.scheduleInterval,
    },
    date: params.date,
    occupiedSlots,
    durationMinutes,
    blockedTimes: blocked.slots,
    localReference: params.localReference ?? getBookingLocalReference(),
  });

  return {
    slots: grid.filter((e) => e.status === 'available').map((e) => e.time),
    durationMinutes,
  };
}

export async function hasPublicSlotConflict(
  tenantId: string,
  barberId: string,
  date: string,
  time: string,
  durationMinutes: number,
  excludeId?: string,
) {
  const occupying = await prisma.appointment.findMany({
    where: {
      tenantId,
      barberId,
      date,
      status: { in: OCCUPYING_STATUSES },
      ...(excludeId ? { NOT: { id: excludeId } } : {}),
    },
    select: { time: true, durationMinutes: true },
  });

  const newSlots = expandOccupiedSlots(time, durationMinutes);
  const occupied = new Set(occupiedFromAppointments(occupying));
  return newSlots.some((slot) => occupied.has(slot));
}

export type CreateBookingRequestInput = {
  slug: string;
  clientName: string;
  clientPhone: string;
  barberId: string;
  date: string;
  time: string;
  serviceIds: string[];
};

export async function createPublicBookingRequest(input: CreateBookingRequestInput) {
  const catalog = await getPublicBookingCatalog(input.slug);
  if (!catalog) return { error: 'not_found' as const };
  if (catalog.disabled) return { error: 'disabled' as const };

  const { tenant } = catalog;
  const phone = input.clientPhone.trim();
  if (!phone) return { error: 'phone_required' as const };

  const barber = await prisma.barber.findFirst({
    where: { id: input.barberId, tenantId: tenant.id, active: true },
  });
  if (!barber) return { error: 'invalid_barber' as const };

  const services = await prisma.service.findMany({
    where: {
      tenantId: tenant.id,
      active: true,
      id: { in: input.serviceIds },
    },
  });
  if (services.length === 0 || services.length !== input.serviceIds.length) {
    return { error: 'invalid_services' as const };
  }

  const durationMinutes = services.reduce((sum, s) => sum + s.durationMinutes, 0);
  try {
    validateServiceDuration(durationMinutes);
  } catch (e) {
    return {
      error: 'invalid_duration' as const,
      message: e instanceof Error ? e.message : 'Duración inválida',
    };
  }

  const blocked = await getBlockedSlots(tenant.id, barber.id, input.date);
  if (blocked.fullDay) return { error: 'slot_unavailable' as const };

  const slotCheck = await getAvailableSlots({
    slug: input.slug,
    barberId: input.barberId,
    date: input.date,
    serviceIds: input.serviceIds,
  });
  if ('error' in slotCheck) return slotCheck;
  if (!slotCheck.slots.includes(input.time)) {
    return { error: 'slot_unavailable' as const };
  }

  const now = new Date();
  const pendingExpiresAt = new Date(now.getTime() + PENDING_HOLD_HOURS * 60 * 60 * 1000);

  const appointment = await prisma.appointment.create({
    data: {
      tenantId: tenant.id,
      barberId: barber.id,
      clientName: input.clientName.trim(),
      clientPhone: phone,
      source: 'client_web' satisfies AppointmentSource,
      date: input.date,
      time: input.time,
      durationMinutes,
      status: 'pending' satisfies AppointmentStatus,
      pendingExpiresAt,
      services: {
        create: services.map((s) => ({
          serviceId: s.id,
          unitPrice: s.price,
          durationMinutes: s.durationMinutes,
        })),
      },
    },
    include: {
      services: { include: { service: { select: { name: true } } } },
      barber: { select: { name: true } },
    },
  });

  void notifyNewPendingRequest({
    tenantId: tenant.id,
    barberId: barber.id,
    appointmentId: appointment.id,
    clientName: appointment.clientName,
    clientPhone: phone,
    date: appointment.date,
    time: appointment.time,
    serviceNames: appointment.services.map((l) => l.service.name),
    barberName: appointment.barber.name,
  });

  return {
    appointment: {
      id: appointment.id,
      status: appointment.status,
      pendingExpiresAt: appointment.pendingExpiresAt?.toISOString() ?? null,
    },
  };
}

export async function expirePendingAppointments() {
  const now = new Date();
  const expired = await prisma.appointment.updateMany({
    where: {
      status: 'pending',
      pendingExpiresAt: { lte: now },
    },
    data: {
      status: 'canceled',
      canceledAt: now,
      updatedAt: now,
    },
  });
  return expired.count;
}
