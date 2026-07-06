import { z } from 'zod';
import { getPublicBookingCatalog } from '@/lib/server/services/booking/publicBooking';
import { notFound } from '@/lib/server/route-helpers';

export const runtime = 'nodejs';

type Ctx = { params: Promise<{ slug: string }> };

export async function GET(_request: Request, context: Ctx) {
  const { slug } = await context.params;
  const catalog = await getPublicBookingCatalog(slug);
  if (!catalog) return notFound('Barbería no encontrada');

  if (catalog.disabled) {
    return Response.json(
      { error: 'Las reservas online no están disponibles para esta barbería.' },
      { status: 403 },
    );
  }

  return Response.json({
    displayName: catalog.displayName,
    logoUrl: catalog.logoUrl,
    scheduleStart: catalog.scheduleStart,
    scheduleEnd: catalog.scheduleEnd,
    scheduleInterval: catalog.scheduleInterval,
    barbers: catalog.barbers,
    services: catalog.services,
  });
}
