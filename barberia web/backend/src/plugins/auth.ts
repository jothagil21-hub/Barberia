import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

export type JwtPayload = {
  sub: string;
  username: string;
  type: 'platform_admin';
};

/** Registra JWT y el decorador authenticatePlatform para rutas protegidas. */
export async function registerAuthPlugin(app: FastifyInstance) {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error('JWT_SECRET es obligatorio en .env');

  await app.register(import('@fastify/jwt'), { secret });

  app.decorate(
    'authenticatePlatform',
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const payload = await request.jwtVerify<JwtPayload>();
        if (payload.type !== 'platform_admin') {
          return reply.status(401).send({ error: 'No autorizado' });
        }
      } catch {
        return reply.status(401).send({ error: 'No autorizado' });
      }
    },
  );
}

declare module 'fastify' {
  interface FastifyInstance {
    authenticatePlatform: (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
}
