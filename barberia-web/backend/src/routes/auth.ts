import bcrypt from 'bcrypt';
import { z } from 'zod';
import type { FastifyInstance } from 'fastify';
import { prisma } from '../lib/prisma.js';

const loginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
});

export async function authRoutes(app: FastifyInstance) {
  app.post('/api/platform/auth/login', async (request, reply) => {
    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Datos de login inválidos' });
    }

    const { username, password } = parsed.data;
    const admin = await prisma.platformAdmin.findUnique({ where: { username } });
    if (!admin || !(await bcrypt.compare(password, admin.passwordHash))) {
      return reply.status(401).send({ error: 'Usuario o contraseña incorrectos' });
    }

    const token = app.jwt.sign(
      { sub: admin.id, username: admin.username, type: 'platform_admin' },
      { expiresIn: '8h' },
    );

    return { token, username: admin.username };
  });
}
