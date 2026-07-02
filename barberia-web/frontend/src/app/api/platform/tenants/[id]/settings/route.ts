import { z } from 'zod';
import { prisma } from '@/lib/server/prisma';
import { badRequest, notFound, routeParams, withPlatformAdmin } from '@/lib/server/route-helpers';
import { validateScheduleConfig } from '@/lib/server/utils/schedule';

export const runtime = 'nodejs';

const settingsSchema = z.object({
  displayName: z.string().min(1).max(120).optional(),
  logoUrl: z.string().url().nullable().optional(),
  scheduleStart: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  scheduleEnd: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  scheduleInterval: z.number().int().optional(),
});

type Ctx = { params: Promise<{ id: string }> };

export async function PUT(request: Request, context: Ctx) {
  return withPlatformAdmin(request, async () => {
    const { id } = await routeParams(context);
    const body = await request.json();
    const parsed = settingsSchema.safeParse(body);
    if (!parsed.success) {
      return badRequest(parsed.error.flatten());
    }

    const tenant = await prisma.tenant.findUnique({
      where: { id },
      include: { settings: true },
    });
    if (!tenant) return notFound('Barbería no encontrada');

    const current = tenant.settings ?? {
      displayName: 'Barbería',
      logoUrl: null,
      scheduleStart: '09:00',
      scheduleEnd: '21:00',
      scheduleInterval: 30,
    };

    const merged = {
      scheduleStart: parsed.data.scheduleStart ?? current.scheduleStart,
      scheduleEnd: parsed.data.scheduleEnd ?? current.scheduleEnd,
      scheduleInterval: parsed.data.scheduleInterval ?? current.scheduleInterval,
    };

    try {
      validateScheduleConfig(merged);
    } catch (e) {
      const message = e instanceof Error ? e.message : 'Horario inválido';
      return badRequest(message);
    }

    const settings = await prisma.tenantSettings.upsert({
      where: { tenantId: tenant.id },
      create: {
        tenantId: tenant.id,
        displayName: parsed.data.displayName ?? current.displayName,
        logoUrl: parsed.data.logoUrl !== undefined ? parsed.data.logoUrl : current.logoUrl,
        ...merged,
      },
      update: {
        ...(parsed.data.displayName !== undefined && { displayName: parsed.data.displayName }),
        ...(parsed.data.logoUrl !== undefined && { logoUrl: parsed.data.logoUrl }),
        ...(parsed.data.scheduleStart !== undefined && { scheduleStart: parsed.data.scheduleStart }),
        ...(parsed.data.scheduleEnd !== undefined && { scheduleEnd: parsed.data.scheduleEnd }),
        ...(parsed.data.scheduleInterval !== undefined && {
          scheduleInterval: parsed.data.scheduleInterval,
        }),
      },
    });

    return Response.json(settings);
  });
}
