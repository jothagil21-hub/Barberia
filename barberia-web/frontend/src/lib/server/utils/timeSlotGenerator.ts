import { SERVICE_DURATION_BLOCK } from '@/lib/server/utils/serviceDuration';
import { expandOccupiedSlots, rangesOverlap, timeToMinutes } from '@/lib/server/utils/appointmentSlots';

export type ScheduleConfig = {
  scheduleStart: string;
  scheduleEnd: string;
  scheduleInterval: number;
};

export type SlotStatus = 'available' | 'pastUnavailable' | 'blocked' | 'booked';

export type SlotEntry = {
  time: string;
  status: SlotStatus;
};

function parseTime(time: string): number {
  const [hours, minutes] = time.split(':').map(Number);
  return hours * 60 + minutes;
}

function formatTime(totalMinutes: number): string {
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
}

export function generateAllSlots(config: ScheduleConfig): string[] {
  const slots: string[] = [];
  let current = parseTime(config.scheduleStart);
  const end = parseTime(config.scheduleEnd);
  while (current < end) {
    slots.push(formatTime(current));
    current += config.scheduleInterval;
  }
  return slots;
}

function slotDateTime(day: Date, slot: string): Date {
  const [hours, minutes] = slot.split(':').map(Number);
  return new Date(day.getFullYear(), day.getMonth(), day.getDate(), hours, minutes);
}

function canFitAtStart(
  startTime: string,
  durationMinutes: number,
  scheduleEnd: string,
  occupiedSlots: Set<string>,
  blockedSlots: Set<string>,
): boolean {
  const slots = expandOccupiedSlots(startTime, durationMinutes);
  const endMinutes = timeToMinutes(scheduleEnd);
  for (const slot of slots) {
    if (timeToMinutes(slot) >= endMinutes) return false;
    if (occupiedSlots.has(slot)) return false;
    if (blockedSlots.has(slot)) return false;
  }
  return true;
}

export function buildBookingGrid(params: {
  config: ScheduleConfig;
  date: string;
  occupiedSlots: string[];
  durationMinutes: number;
  blockedTimes?: string[];
  reference?: Date;
  /** Hoy y hora actual en el navegador del cliente (evita UTC en Vercel). */
  localReference?: { date: string; minutesSinceMidnight: number };
}): SlotEntry[] {
  const {
    config,
    date,
    occupiedSlots,
    durationMinutes,
    blockedTimes = [],
    reference = new Date(),
    localReference,
  } = params;

  const day = new Date(`${date}T12:00:00`);
  const referenceDate = localReference
    ? localReference.date
    : (() => {
        const today = new Date(reference.getFullYear(), reference.getMonth(), reference.getDate());
        const y = today.getFullYear();
        const m = String(today.getMonth() + 1).padStart(2, '0');
        const d = String(today.getDate()).padStart(2, '0');
        return `${y}-${m}-${d}`;
      })();
  const isPastDate = date < referenceDate;
  const isToday = date === referenceDate;

  const occupiedSet = new Set(occupiedSlots);
  const blockedSet = new Set(blockedTimes);
  const entries: SlotEntry[] = [];

  let current = parseTime(config.scheduleStart);
  const end = parseTime(config.scheduleEnd);
  const step = Math.min(config.scheduleInterval, SERVICE_DURATION_BLOCK);

  while (current < end) {
    const slot = formatTime(current);
    const isPast = isPastDate
      || (localReference
        ? isToday && current < localReference.minutesSinceMidnight
        : isToday && slotDateTime(day, slot) < reference);
    const slotOccupied = occupiedSet.has(slot);
    const slotBlocked = blockedSet.has(slot);
    const fits = canFitAtStart(
      slot,
      durationMinutes,
      config.scheduleEnd,
      occupiedSet,
      blockedSet,
    );

    if (!fits) {
      if (slotOccupied) {
        entries.push({ time: slot, status: 'booked' });
      } else if (slotBlocked) {
        entries.push({ time: slot, status: 'blocked' });
      } else {
        entries.push({ time: slot, status: 'pastUnavailable' });
      }
    } else if (isPast) {
      entries.push({ time: slot, status: 'pastUnavailable' });
    } else {
      entries.push({ time: slot, status: 'available' });
    }

    current += step;
  }

  return entries;
}

export function occupiedFromAppointments(
  appointments: { time: string; durationMinutes: number }[],
): string[] {
  const occupied = new Set<string>();
  for (const appt of appointments) {
    for (const slot of expandOccupiedSlots(appt.time, appt.durationMinutes)) {
      occupied.add(slot);
    }
  }
  return [...occupied].sort();
}

export { rangesOverlap };
