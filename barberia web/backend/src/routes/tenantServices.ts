import type { FastifyInstance } from 'fastify';
import { prisma } from '../lib/prisma.js';

export async function tenantServicesRoutes(app: FastifyInstance) {
  app.addHook('onRequest', app.authenticatePlatform);

  app.get<{ Params: { id: string } }>(
    '/api/platform/tenants/:id/services',
    async (request, reply) => {
      const tenant = await prisma.tenant.findUnique({
        where: { id: request.params.id },
        include: { settings: true },
      });
      if (!tenant) {
        return reply.status(404).send({ error: 'Barbería no encontrada' });
      }

      const services = await prisma.service.findMany({
        where: { tenantId: tenant.id },
        orderBy: [{ active: 'desc' }, { name: 'asc' }],
      });

      return {
        tenantName: tenant.settings?.displayName ?? tenant.name,
        services: services.map((s) => ({
          id: s.id,
          name: s.name,
          price: s.price,
          durationMinutes: s.durationMinutes,
          active: s.active,
          updatedAt: s.updatedAt.toISOString(),
        })),
      };
    },
  );
}
