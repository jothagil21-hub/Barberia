import { SERVICE_DURATION_BLOCK } from './serviceDuration.js';

export function timeToMinutes(time: string): number {
  const [hours, minutes] = time.split(':').map(Number);
  return hours * 60 + minutes;
}

export function rangesOverlap(
  startA: string,
  durationA: number,
  startB: string,
  durationB: number,
): boolean {
  const aStart = timeToMinutes(startA);
  const aEnd = aStart + durationA;
  const bStart = timeToMinutes(startB);
  const bEnd = bStart + durationB;
  return aStart < bEnd && bStart < aEnd;
}

export function expandOccupiedSlots(startTime: string, durationMinutes: number): string[] {
  const start = timeToMinutes(startTime);
  const slots: string[] = [];
  for (let offset = 0; offset < durationMinutes; offset += SERVICE_DURATION_BLOCK) {
    const total = start + offset;
    const hours = Math.floor(total / 60);
    const minutes = total % 60;
    slots.push(
      `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`,
    );
  }
  return slots;
}
