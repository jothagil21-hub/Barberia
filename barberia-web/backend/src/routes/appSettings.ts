import type { FastifyInstance } from 'fastify';
import { deleteTenantLogo, saveTenantLogo } from '../services/tenantLogo.js';

export async function appSettingsRoutes(app: FastifyInstance) {
  app.post(
    '/api/app/settings/logo',
    { preHandler: [app.authenticateTenantUser] },
    async (request, reply) => {
      const tenantId = request.appUser!.tenantId;
      const file = await request.file();
      if (!file) return reply.status(400).send({ error: 'No se envió ningún archivo' });

      try {
        const settings = await saveTenantLogo(tenantId, file);
        return { logoUrl: settings.logoUrl };
      } catch (e) {
        const message = e instanceof Error ? e.message : 'Error al guardar logo';
        return reply.status(400).send({ error: message });
      }
    },
  );

  app.delete(
    '/api/app/settings/logo',
    { preHandler: [app.authenticateTenantUser] },
    async (request) => {
      const tenantId = request.appUser!.tenantId;
      await deleteTenantLogo(tenantId);
      return { logoUrl: null };
    },
  );
}
