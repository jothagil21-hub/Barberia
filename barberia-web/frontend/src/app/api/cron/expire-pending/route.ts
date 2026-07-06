import { expirePendingAppointments } from '@/lib/server/services/booking/publicBooking';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  const secret = process.env.CRON_SECRET;
  if (!secret) {
    return Response.json({ error: 'CRON_SECRET no configurado' }, { status: 503 });
  }

  const auth = request.headers.get('authorization');
  if (auth !== `Bearer ${secret}`) {
    return Response.json({ error: 'No autorizado' }, { status: 401 });
  }

  const expired = await expirePendingAppointments();
  return Response.json({ expired, ok: true });
}
