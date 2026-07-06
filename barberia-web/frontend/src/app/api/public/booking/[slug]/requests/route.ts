import { z } from 'zod';
import { createPublicBookingRequest } from '@/lib/server/services/booking/publicBooking';
import { badRequest, notFound } from '@/lib/server/route-helpers';

export const runtime = 'nodejs';

const bodySchema = z.object({
  clientName: z.string().trim().min(1).max(120),
  clientPhone: z.string().trim().min(6).max(30),
  barberId: z.string().uuid(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  time: z.string().regex(/^\d{2}:\d{2}$/),
  serviceIds: z.array(z.string().uuid()).min(1),
});

type Ctx = { params: Promise<{ slug: string }> };

export async function POST(request: Request, context: Ctx) {
  const { slug } = await context.params;
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return badRequest('Cuerpo JSON inválido');
  }

  const parsed = bodySchema.safeParse(body);
  if (!parsed.success) {
    return badRequest(parsed.error.flatten());
  }

  const result = await createPublicBookingRequest({
    slug,
    ...parsed.data,
  });

  if ('error' in result) {
    switch (result.error) {
      case 'not_found':
        return notFound('Barbería no encontrada');
      case 'disabled':
        return Response.json({ error: 'Reservas online desactivadas' }, { status: 403 });
      case 'phone_required':
        return badRequest('El teléfono es obligatorio');
      case 'slot_unavailable':
        return Response.json(
          { error: 'El horario ya no está disponible. Elige otro.' },
          { status: 409 },
        );
      default:
        return badRequest('Datos inválidos');
    }
  }

  if (!('appointment' in result)) {
    return badRequest('No se pudo crear la solicitud');
  }

  return Response.json(
    {
      message:
        'Solicitud enviada. La barbería confirmará tu cita en las próximas 24 horas.',
      appointment: result.appointment,
    },
    { status: 201 },
  );
}
