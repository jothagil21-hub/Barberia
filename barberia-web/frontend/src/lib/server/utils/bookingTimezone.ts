const DEFAULT_BOOKING_TIMEZONE = 'America/Bogota';

export function getBookingTimezone(): string {
  const configured = process.env.BOOKING_TIMEZONE?.trim();
  return configured || DEFAULT_BOOKING_TIMEZONE;
}

export type BookingLocalReference = {
  date: string;
  minutesSinceMidnight: number;
};

/** Hora civil actual en la zona de reservas (fallback cuando el cliente no envía referenceDate/Minutes). */
export function getBookingLocalReference(now = new Date()): BookingLocalReference {
  const timeZone = getBookingTimezone();
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(now);

  const get = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value ?? '0';

  const year = get('year');
  const month = get('month');
  const day = get('day');
  const hour = Number(get('hour'));
  const minute = Number(get('minute'));

  return {
    date: `${year}-${month}-${day}`,
    minutesSinceMidnight: hour * 60 + minute,
  };
}

export function formatBookingTime(now = new Date()): string {
  return new Intl.DateTimeFormat('es-CO', {
    timeZone: getBookingTimezone(),
    dateStyle: 'full',
    timeStyle: 'long',
  }).format(now);
}

export function timeToMinutesSinceMidnight(time: string): number {
  const [hours, minutes] = time.split(':').map(Number);
  return hours * 60 + minutes;
}

/** true si la fecha/hora de la cita ya pasó en la zona de reservas. */
export function isBookingSlotInPast(
  date: string,
  time: string,
  now = new Date(),
): boolean {
  const ref = getBookingLocalReference(now);
  if (date < ref.date) return true;
  if (date > ref.date) return false;
  return timeToMinutesSinceMidnight(time) < ref.minutesSinceMidnight;
}
