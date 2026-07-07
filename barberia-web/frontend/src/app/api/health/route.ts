import {
  formatBookingTime,
  getBookingLocalReference,
  getBookingTimezone,
} from '@/lib/server/utils/bookingTimezone';

export const runtime = 'nodejs';

export async function GET() {
  const now = new Date();
  const localReference = getBookingLocalReference(now);

  return Response.json({
    status: 'ok',
    serverUtc: now.toISOString(),
    bookingTimezone: getBookingTimezone(),
    bookingLocal: formatBookingTime(now),
    bookingLocalReference: localReference,
  });
}
