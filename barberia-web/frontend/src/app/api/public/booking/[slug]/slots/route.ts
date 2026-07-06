import { z } from 'zod';
import { getAvailableSlots } from '@/lib/server/services/booking/publicBooking';
import { badRequest, notFound } from '@/lib/server/route-helpers';

export const runtime = 'nodejs';

const querySchema = z.object({
  barberId: z.string().uuid(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  serviceIds: z.string().min(1),
});

type Ctx = { params: Promise<{ slug: string }> };

export async function GET(request: Request, context: Ctx) {
  const { slug } = await context.params;
  const url = new URL(request.url);
  const parsed = querySchema.safeParse({
    barberId: url.searchParams.get('barberId'),
    date: url.searchParams.get('date'),
    serviceIds: url.searchParams.get('serviceIds'),
  });
  if (!parsed.success) {
    return badRequest('Parámetros barberId, date y serviceIds requeridos');
  }

  const serviceIds = parsed.data.serviceIds.split(',').filter(Boolean);
  const result = await getAvailableSlots({
    slug,
    barberId: parsed.data.barberId,
    date: parsed.data.date,
    serviceIds,
  });

  if ('error' in result) {
    if (result.error === 'not_found') return notFound('Barbería no encontrada');
    if (result.error === 'disabled') {
      return Response.json({ error: 'Reservas online desactivadas' }, { status: 403 });
    }
    return badRequest(result.message ?? 'Parámetros inválidos');
  }

  return Response.json(result);
}
