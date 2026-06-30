import bcrypt from 'bcrypt';
import { z } from 'zod';
import type { FastifyInstance } from 'fastify';
import { prisma } from '../lib/prisma.js';

const createUserSchema = z.object({
  username: z.string().min(1).max(60),
  password: z.string().min(4).max(120),
  role: z.enum(['owner', 'staff']).default('staff'),
});

const patchUserSchema = z.object({
  active: z.boolean().optional(),
  role: z.enum(['owner', 'staff']).optional(),
  password: z.string().min(4).max(120).optional(),
});

function toPublic(user: {
  id: string;
  username: string;
  role: string;
  active: boolean;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: user.id,
    username: user.username,
    role: user.role,
    active: user.active,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

export async function userRoutes(app: FastifyInstance) {
  app.addHook('onRequest', app.authenticatePlatform);

  app.get<{ Params: { id: string } }>(
    '/api/platform/tenants/:id/users',
    async (request, reply) => {
      const tenant = await prisma.tenant.findUnique({ where: { id: request.params.id } });
      if (!tenant) return reply.status(404).send({ error: 'Barbería no encontrada' });

      const users = await prisma.tenantUser.findMany({
        where: { tenantId: tenant.id },
        orderBy: { createdAt: 'desc' },
      });
      return users.map(toPublic);
    },
  );

  app.post<{ Params: { id: string } }>(
    '/api/platform/tenants/:id/users',
    async (request, reply) => {
      const parsed = createUserSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({ error: parsed.error.flatten() });
      }

      const tenant = await prisma.tenant.findUnique({ where: { id: request.params.id } });
      if (!tenant) return reply.status(404).send({ error: 'Barbería no encontrada' });

      const exists = await prisma.tenantUser.findUnique({
        where: {
          tenantId_username: { tenantId: tenant.id, username: parsed.data.username },
        },
      });
      if (exists) {
        return reply.status(409).send({ error: 'Ese usuario ya existe en esta barbería' });
      }

      const user = await prisma.tenantUser.create({
        data: {
          tenantId: tenant.id,
          username: parsed.data.username,
          passwordHash: await bcrypt.hash(parsed.data.password, 10),
          role: parsed.data.role,
        },
      });

      return reply.status(201).send(toPublic(user));
    },
  );

  app.patch<{ Params: { id: string; userId: string } }>(
    '/api/platform/tenants/:id/users/:userId',
    async (request, reply) => {
      const parsed = patchUserSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({ error: parsed.error.flatten() });
      }

      const user = await prisma.tenantUser.findFirst({
        where: { id: request.params.userId, tenantId: request.params.id },
      });
      if (!user) return reply.status(404).send({ error: 'Usuario no encontrado' });

      const data: { active?: boolean; role?: 'owner' | 'staff'; passwordHash?: string } = {};
      if (parsed.data.active !== undefined) data.active = parsed.data.active;
      if (parsed.data.role !== undefined) data.role = parsed.data.role;
      if (parsed.data.password) {
        data.passwordHash = await bcrypt.hash(parsed.data.password, 10);
      }

      const updated = await prisma.tenantUser.update({ where: { id: user.id }, data });
      return toPublic(updated);
    },
  );
}
