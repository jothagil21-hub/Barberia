import { z } from 'zod';
import type { FastifyInstance } from 'fastify';
import { prisma } from '../lib/prisma.js';
import { saveTenantLogo } from '../services/tenantLogo.js';
import { slugify, validateScheduleConfig } from '../utils/schedule.js';

const createTenantSchema = z.object({
  name: z.string().min(1).max(120),
  slug: z.string().min(1).max(80).optional(),
});

const patchTenantSchema = z.object({
  name: z.string().min(1).max(120).optional(),
  active: z.boolean().optional(),
});

const settingsSchema = z.object({
  displayName: z.string().min(1).max(120).optional(),
  logoUrl: z.string().url().nullable().optional(),
  scheduleStart: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  scheduleEnd: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  scheduleInterval: z.number().int().optional(),
});

function tenantSelect() {
  return {
    id: true,
    name: true,
    slug: true,
    active: true,
    createdAt: true,
    updatedAt: true,
    settings: true,
    _count: { select: { users: true } },
  } as const;
}

function formatTenant(t: {
  id: string;
  name: string;
  slug: string;
  active: boolean;
  createdAt: Date;
  updatedAt: Date;
  settings: unknown;
  _count: { users: number };
}) {
  return {
    id: t.id,
    name: t.name,
    slug: t.slug,
    active: t.active,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
    settings: t.settings,
    userCount: t._count.users,
  };
}

export async function tenantRoutes(app: FastifyInstance) {
  app.addHook('onRequest', app.authenticatePlatform);

  app.get('/api/platform/tenants', async () => {
    const tenants = await prisma.tenant.findMany({
      orderBy: { createdAt: 'desc' },
      select: tenantSelect(),
    });
    return tenants.map(formatTenant);
  });

  app.post('/api/platform/tenants', async (request, reply) => {
    const parsed = createTenantSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: parsed.error.flatten() });
    }

    let slug = parsed.data.slug ?? slugify(parsed.data.name);
    if (await prisma.tenant.findUnique({ where: { slug } })) {
      slug = `${slug}-${Date.now().toString(36)}`;
    }

    const tenant = await prisma.tenant.create({
      data: {
        name: parsed.data.name,
        slug,
        settings: { create: {} },
      },
      select: tenantSelect(),
    });

    return reply.status(201).send(formatTenant(tenant));
  });

  app.get<{ Params: { id: string } }>('/api/platform/tenants/:id', async (request, reply) => {
    const tenant = await prisma.tenant.findUnique({
      where: { id: request.params.id },
      select: tenantSelect(),
    });
    if (!tenant) return reply.status(404).send({ error: 'Barbería no encontrada' });
    return formatTenant(tenant);
  });

  app.patch<{ Params: { id: string } }>('/api/platform/tenants/:id', async (request, reply) => {
    const parsed = patchTenantSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: parsed.error.flatten() });
    }

    const exists = await prisma.tenant.findUnique({ where: { id: request.params.id } });
    if (!exists) return reply.status(404).send({ error: 'Barbería no encontrada' });

    const tenant = await prisma.tenant.update({
      where: { id: request.params.id },
      data: parsed.data,
      select: tenantSelect(),
    });

    return formatTenant(tenant);
  });

  app.put<{ Params: { id: string } }>(
    '/api/platform/tenants/:id/settings',
    async (request, reply) => {
      const parsed = settingsSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({ error: parsed.error.flatten() });
      }

      const tenant = await prisma.tenant.findUnique({
        where: { id: request.params.id },
        include: { settings: true },
      });
      if (!tenant) return reply.status(404).send({ error: 'Barbería no encontrada' });

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
        return reply.status(400).send({ error: message });
      }

      return prisma.tenantSettings.upsert({
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
    },
  );

  app.post<{ Params: { id: string } }>(
    '/api/platform/tenants/:id/logo',
    async (request, reply) => {
      const tenant = await prisma.tenant.findUnique({ where: { id: request.params.id } });
      if (!tenant) return reply.status(404).send({ error: 'Barbería no encontrada' });

      const file = await request.file();
      if (!file) return reply.status(400).send({ error: 'No se envió ningún archivo' });

      try {
        return saveTenantLogo(tenant.id, file);
      } catch (e) {
        const message = e instanceof Error ? e.message : 'Error al guardar logo';
        return reply.status(400).send({ error: message });
      }
    },
  );
}
