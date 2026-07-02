import type { TenantUserRole } from '@prisma/client';
import { prisma } from '@/lib/server/prisma';
import { rangesOverlap } from '@/lib/server/utils/appointmentSlots';
import { validateServiceDuration } from '@/lib/server/utils/serviceDuration';
import { validateScheduleConfig } from '@/lib/server/utils/schedule';
import { buildPullBundle, parseAppointmentStatus } from '@/lib/server/services/sync/buildPull';
import {
  isStaff,
  staffBarberScopeConflict,
  staffForbiddenConflict,
  type SyncActor,
} from '@/lib/server/services/sync/staffPermissions';
import type {
  AppliedIds,
  SyncChanges,
  SyncConflict,
  SyncPostResult,
  UpsertAppointment,
  UpsertBarber,
  UpsertPosInvoice,
  UpsertScheduleBlock,
  UpsertService,
} from '@/lib/server/services/sync/types';

function parseDate(value: string) {
  return new Date(value);
}

function isNewer(incoming: string, existing: Date) {
  return parseDate(incoming).getTime() > existing.getTime();
}

async function hasSlotConflict(
  tenantId: string,
  barberId: string,
  date: string,
  time: string,
  durationMinutes: number,
  excludeId?: string,
) {
  const scheduled = await prisma.appointment.findMany({
    where: {
      tenantId,
      barberId,
      date,
      status: 'scheduled',
      ...(excludeId ? { NOT: { id: excludeId } } : {}),
    },
    select: { time: true, durationMinutes: true },
  });

  return scheduled.some((existing) =>
    rangesOverlap(time, durationMinutes, existing.time, existing.durationMinutes),
  );
}

async function upsertBarber(
  tenantId: string,
  item: UpsertBarber,
  applied: AppliedIds,
  conflicts: SyncConflict[],
) {
  if (item.id) {
    const existing = await prisma.barber.findFirst({
      where: { id: item.id, tenantId },
    });
    if (!existing) {
      conflicts.push({
        entity: 'barber',
        clientId: item.clientId,
        serverId: item.id,
        reason: 'Barbero no encontrado',
      });
      return;
    }
    if (!isNewer(item.updatedAt, existing.updatedAt)) return;

    await prisma.barber.update({
      where: { id: existing.id },
      data: { name: item.name, active: item.active, updatedAt: parseDate(item.updatedAt) },
    });
    if (item.clientId) applied.barbers[item.clientId] = existing.id;
    return;
  }

  const created = await prisma.barber.create({
    data: {
      tenantId,
      name: item.name,
      active: item.active,
      updatedAt: parseDate(item.updatedAt),
    },
  });
  if (item.clientId) applied.barbers[item.clientId] = created.id;
}

async function upsertService(
  tenantId: string,
  item: UpsertService,
  applied: AppliedIds,
  conflicts: SyncConflict[],
) {
  try {
    validateServiceDuration(item.durationMinutes);
  } catch (e) {
    conflicts.push({
      entity: 'service',
      clientId: item.clientId,
      serverId: item.id,
      reason: e instanceof Error ? e.message : 'Duración inválida',
    });
    return;
  }

  if (item.id) {
    const existing = await prisma.service.findFirst({
      where: { id: item.id, tenantId },
    });
    if (!existing) {
      conflicts.push({
        entity: 'service',
        clientId: item.clientId,
        serverId: item.id,
        reason: 'Servicio no encontrado',
      });
      return;
    }
    if (!isNewer(item.updatedAt, existing.updatedAt)) return;

    await prisma.service.update({
      where: { id: existing.id },
      data: {
        name: item.name,
        price: item.price,
        durationMinutes: item.durationMinutes,
        active: item.active,
        updatedAt: parseDate(item.updatedAt),
      },
    });
    if (item.clientId) applied.services[item.clientId] = existing.id;
    return;
  }

  const created = await prisma.service.create({
    data: {
      tenantId,
      name: item.name,
      price: item.price,
      durationMinutes: item.durationMinutes,
      active: item.active,
      updatedAt: parseDate(item.updatedAt),
    },
  });
  if (item.clientId) applied.services[item.clientId] = created.id;
}

async function upsertAppointment(
  tenantId: string,
  item: UpsertAppointment,
  applied: AppliedIds,
  conflicts: SyncConflict[],
  actor?: SyncActor,
) {
  if (actor && isStaff(actor)) {
    if (!actor.barberId || item.barberId !== actor.barberId) {
      conflicts.push(staffBarberScopeConflict(item.clientId, item.id));
      return;
    }
  }

  const status = parseAppointmentStatus(item.status);

  if (status === 'scheduled') {
    const excludeId = item.id;
    const conflict = await hasSlotConflict(
      tenantId,
      item.barberId,
      item.date,
      item.time,
      item.durationMinutes,
      excludeId,
    );
    if (conflict) {
      conflicts.push({
        entity: 'appointment',
        clientId: item.clientId,
        serverId: item.id,
        reason: 'El horario ya está ocupado para ese barbero',
      });
      return;
    }
  }

  if (item.id) {
    const existing = await prisma.appointment.findFirst({
      where: { id: item.id, tenantId },
    });
    if (!existing) {
      conflicts.push({
        entity: 'appointment',
        clientId: item.clientId,
        serverId: item.id,
        reason: 'Cita no encontrada',
      });
      return;
    }
    if (actor && isStaff(actor) && existing.barberId !== actor.barberId) {
      conflicts.push(staffBarberScopeConflict(item.clientId, item.id));
      return;
    }
    if (!isNewer(item.updatedAt, existing.updatedAt)) return;

    await prisma.$transaction(async (tx) => {
      await tx.appointment.update({
        where: { id: existing.id },
        data: {
          barberId: item.barberId,
          clientName: item.clientName,
          date: item.date,
          time: item.time,
          durationMinutes: item.durationMinutes,
          status,
          canceledAt: item.canceledAt ? parseDate(item.canceledAt) : null,
          updatedAt: parseDate(item.updatedAt),
        },
      });
      await tx.appointmentService.deleteMany({ where: { appointmentId: existing.id } });
      if (item.services.length > 0) {
        await tx.appointmentService.createMany({
          data: item.services.map((s) => ({
            appointmentId: existing.id,
            serviceId: s.serviceId,
            unitPrice: s.unitPrice,
            durationMinutes: s.durationMinutes,
          })),
        });
      }
    });
    if (item.clientId) applied.appointments[item.clientId] = existing.id;
    return;
  }

  const created = await prisma.appointment.create({
    data: {
      tenantId,
      barberId: item.barberId,
      clientName: item.clientName,
      date: item.date,
      time: item.time,
      durationMinutes: item.durationMinutes,
      status,
      createdAt: item.createdAt ? parseDate(item.createdAt) : undefined,
      canceledAt: item.canceledAt ? parseDate(item.canceledAt) : null,
      updatedAt: parseDate(item.updatedAt),
      services: {
        create: item.services.map((s) => ({
          serviceId: s.serviceId,
          unitPrice: s.unitPrice,
          durationMinutes: s.durationMinutes,
        })),
      },
    },
  });
  if (item.clientId) applied.appointments[item.clientId] = created.id;
}

async function upsertPosInvoice(
  tenantId: string,
  item: UpsertPosInvoice,
  applied: AppliedIds,
  conflicts: SyncConflict[],
) {
  const appointment = await prisma.appointment.findFirst({
    where: { id: item.appointmentId, tenantId },
  });
  if (!appointment) {
    conflicts.push({
      entity: 'posInvoice',
      clientId: item.clientId,
      serverId: item.id,
      reason: 'Cita no encontrada para el comprobante',
    });
    return;
  }
  if (appointment.status !== 'attended') {
    conflicts.push({
      entity: 'posInvoice',
      clientId: item.clientId,
      serverId: item.id,
      reason: 'Solo se emiten comprobantes para citas con asistencia',
    });
    return;
  }

  const existingByAppointment = await prisma.posInvoice.findUnique({
    where: { appointmentId: item.appointmentId },
  });
  if (existingByAppointment) {
    if (item.id && existingByAppointment.id !== item.id) {
      conflicts.push({
        entity: 'posInvoice',
        clientId: item.clientId,
        serverId: item.id,
        reason: 'Ya existe un comprobante para esta cita',
      });
      return;
    }
    if (!isNewer(item.updatedAt, existingByAppointment.updatedAt)) return;
    await prisma.posInvoice.update({
      where: { id: existingByAppointment.id },
      data: {
        clientName: item.clientName,
        barberName: item.barberName ?? null,
        subtotal: item.subtotal,
        lines: item.lines,
        issuedAt: parseDate(item.issuedAt),
        updatedAt: parseDate(item.updatedAt),
      },
    });
    if (item.clientId) applied.posInvoices[item.clientId] = existingByAppointment.id;
    return;
  }

  if (item.id) {
    const existing = await prisma.posInvoice.findFirst({
      where: { id: item.id, tenantId },
    });
    if (!existing) {
      conflicts.push({
        entity: 'posInvoice',
        clientId: item.clientId,
        serverId: item.id,
        reason: 'Comprobante no encontrado',
      });
      return;
    }
    if (!isNewer(item.updatedAt, existing.updatedAt)) return;
    await prisma.posInvoice.update({
      where: { id: existing.id },
      data: {
        clientName: item.clientName,
        barberName: item.barberName ?? null,
        subtotal: item.subtotal,
        lines: item.lines,
        issuedAt: parseDate(item.issuedAt),
        updatedAt: parseDate(item.updatedAt),
      },
    });
    if (item.clientId) applied.posInvoices[item.clientId] = existing.id;
    return;
  }

  const maxNumber = await prisma.posInvoice.aggregate({
    where: { tenantId },
    _max: { number: true },
  });
  const number = (maxNumber._max.number ?? 0) + 1;

  const created = await prisma.posInvoice.create({
    data: {
      tenantId,
      appointmentId: item.appointmentId,
      number,
      issuedAt: parseDate(item.issuedAt),
      clientName: item.clientName,
      barberName: item.barberName ?? null,
      subtotal: item.subtotal,
      lines: item.lines,
      updatedAt: parseDate(item.updatedAt),
    },
  });
  if (item.clientId) applied.posInvoices[item.clientId] = created.id;
}

async function upsertScheduleBlock(
  tenantId: string,
  item: UpsertScheduleBlock,
  applied: AppliedIds,
  conflicts: SyncConflict[],
) {
  if (item.id) {
    const existing = await prisma.scheduleBlock.findFirst({
      where: { id: item.id, tenantId },
    });
    if (!existing) {
      conflicts.push({
        entity: 'scheduleBlock',
        clientId: item.clientId,
        serverId: item.id,
        reason: 'Bloqueo no encontrado',
      });
      return;
    }
    if (!isNewer(item.updatedAt, existing.updatedAt)) return;

    await prisma.scheduleBlock.update({
      where: { id: existing.id },
      data: {
        barberId: item.barberId,
        date: item.date,
        time: item.time ?? null,
        isFullDay: item.isFullDay,
        updatedAt: parseDate(item.updatedAt),
      },
    });
    if (item.clientId) applied.scheduleBlocks[item.clientId] = existing.id;
    return;
  }

  const created = await prisma.scheduleBlock.create({
    data: {
      tenantId,
      barberId: item.barberId,
      date: item.date,
      time: item.time ?? null,
      isFullDay: item.isFullDay,
      createdAt: item.createdAt ? parseDate(item.createdAt) : undefined,
      updatedAt: parseDate(item.updatedAt),
    },
  });
  if (item.clientId) applied.scheduleBlocks[item.clientId] = created.id;
}

async function applySettings(
  tenantId: string,
  role: TenantUserRole,
  settings: NonNullable<SyncChanges['settings']>,
  conflicts: SyncConflict[],
) {
  if (role !== 'owner') {
    conflicts.push({
      entity: 'settings',
      reason: 'Solo el owner puede modificar la configuración',
    });
    return;
  }

  const tenant = await prisma.tenant.findUnique({
    where: { id: tenantId },
    include: { settings: true },
  });
  if (!tenant?.settings) return;

  const currentUpdated = tenant.settings.updatedAt;
  if (settings.updatedAt && !isNewer(settings.updatedAt, currentUpdated)) {
    return;
  }

  if (settings.shopName) {
    await prisma.tenant.update({
      where: { id: tenantId },
      data: { name: settings.shopName },
    });
  }

  const merged = {
    scheduleStart: settings.scheduleStart ?? tenant.settings.scheduleStart,
    scheduleEnd: settings.scheduleEnd ?? tenant.settings.scheduleEnd,
    scheduleInterval: settings.scheduleInterval ?? tenant.settings.scheduleInterval,
  };

  try {
    validateScheduleConfig(merged);
  } catch (e) {
    conflicts.push({
      entity: 'settings',
      reason: e instanceof Error ? e.message : 'Horario inválido',
    });
    return;
  }

  await prisma.tenantSettings.update({
    where: { tenantId },
    data: {
      displayName: settings.displayName ?? tenant.settings.displayName,
      scheduleStart: merged.scheduleStart,
      scheduleEnd: merged.scheduleEnd,
      scheduleInterval: merged.scheduleInterval,
      ...(settings.updatedAt ? { updatedAt: parseDate(settings.updatedAt) } : {}),
    },
  });
}

export async function applySyncChanges(
  tenantId: string,
  actor: SyncActor,
  changes: SyncChanges,
  since?: Date,
): Promise<SyncPostResult> {
  const applied: AppliedIds = {
    barbers: {},
    services: {},
    appointments: {},
    scheduleBlocks: {},
    posInvoices: {},
  };
  const conflicts: SyncConflict[] = [];
  const staff = isStaff(actor);

  if (staff) {
    for (const item of changes.barbers ?? []) {
      conflicts.push(staffForbiddenConflict('barber', item.clientId, item.id));
    }
    for (const item of changes.services ?? []) {
      conflicts.push(staffForbiddenConflict('service', item.clientId, item.id));
    }
    for (const item of changes.scheduleBlocks ?? []) {
      conflicts.push(staffForbiddenConflict('scheduleBlock', item.clientId, item.id));
    }
    for (const item of changes.posInvoices ?? []) {
      conflicts.push(staffForbiddenConflict('posInvoice', item.clientId, item.id));
    }
    if (changes.settings) {
      conflicts.push(staffForbiddenConflict('settings'));
    }
    for (const item of changes.appointments ?? []) {
      await upsertAppointment(tenantId, item, applied, conflicts, actor);
    }
  } else {
    for (const item of changes.barbers ?? []) {
      await upsertBarber(tenantId, item, applied, conflicts);
    }
    for (const item of changes.services ?? []) {
      await upsertService(tenantId, item, applied, conflicts);
    }
    for (const item of changes.appointments ?? []) {
      await upsertAppointment(tenantId, item, applied, conflicts, actor);
    }
    for (const item of changes.scheduleBlocks ?? []) {
      await upsertScheduleBlock(tenantId, item, applied, conflicts);
    }
    for (const item of changes.posInvoices ?? []) {
      await upsertPosInvoice(tenantId, item, applied, conflicts);
    }
    if (changes.settings) {
      await applySettings(tenantId, actor.role, changes.settings, conflicts);
    }
  }

  const pull = await buildPullBundle(tenantId, since, actor);

  return {
    serverTime: pull.serverTime,
    applied,
    conflicts,
    pull,
  };
}
