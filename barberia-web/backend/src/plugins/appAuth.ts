import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

export type AppJwtPayload = {
  sub: string;
  username: string;
  tenantId: string;
  role: 'owner' | 'staff';
  type: 'tenant_user';
};

/** JWT y decorador authenticateTenantUser para la app móvil. */
export async function registerAppAuthPlugin(app: FastifyInstance) {
  app.decorate(
    'authenticateTenantUser',
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const payload = await request.jwtVerify<AppJwtPayload>();
        if (payload.type !== 'tenant_user') {
          return reply.status(401).send({ error: 'No autorizado' });
        }
        request.appUser = payload;
      } catch {
        return reply.status(401).send({ error: 'No autorizado' });
      }
    },
  );
}

declare module 'fastify' {
  interface FastifyInstance {
    authenticateTenantUser: (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
  interface FastifyRequest {
    appUser?: AppJwtPayload;
  }
}
