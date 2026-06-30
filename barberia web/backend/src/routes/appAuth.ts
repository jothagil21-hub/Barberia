import bcrypt from 'bcrypt';
import { z } from 'zod';
import type { FastifyInstance } from 'fastify';
import { prisma } from '../lib/prisma.js';

const loginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
});

export async function appAuthRoutes(app: FastifyInstance) {
  app.post('/api/app/auth/login', async (request, reply) => {
    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Datos de login inválidos' });
    }

    const { username, password } = parsed.data;
    const user = await prisma.tenantUser.findFirst({
      where: { username, active: true },
      include: { tenant: { include: { settings: true } } },
    });

    if (
      !user ||
      !user.tenant.active ||
      !(await bcrypt.compare(password, user.passwordHash))
    ) {
      return reply.status(401).send({ error: 'Usuario o contraseña incorrectos' });
    }

    const token = app.jwt.sign(
      {
        sub: user.id,
        username: user.username,
        tenantId: user.tenantId,
        role: user.role,
        type: 'tenant_user',
      },
      { expiresIn: '7d' },
    );

    return {
      token,
      tenant: {
        id: user.tenant.id,
        name: user.tenant.name,
        slug: user.tenant.slug,
        active: user.tenant.active,
      },
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        active: user.active,
      },
    };
  });

  app.get(
    '/api/app/auth/me',
    { onRequest: [app.authenticateTenantUser] },
    async (request, reply) => {
      const payload = request.appUser!;
      const user = await prisma.tenantUser.findUnique({
        where: { id: payload.sub },
        include: { tenant: { include: { settings: true } } },
      });

      if (!user || !user.active || !user.tenant.active) {
        return reply.status(401).send({ error: 'Sesión inválida' });
      }

      return {
        tenant: {
          id: user.tenant.id,
          name: user.tenant.name,
          slug: user.tenant.slug,
          active: user.tenant.active,
        },
        user: {
          id: user.id,
          username: user.username,
          role: user.role,
          active: user.active,
        },
      };
    },
  );
}
