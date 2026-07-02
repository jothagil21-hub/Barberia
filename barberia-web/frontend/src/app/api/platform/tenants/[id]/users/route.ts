import bcrypt from 'bcrypt';
import { z } from 'zod';
import { prisma } from '@/lib/server/prisma';
import { badRequest, notFound, routeParams, withPlatformAdmin } from '@/lib/server/route-helpers';
import { toPublicUser } from '@/lib/server/tenants/format';

export const runtime = 'nodejs';

const createUserSchema = z.object({
  username: z.string().min(1).max(60),
  password: z.string().min(4).max(120),
  role: z.enum(['owner', 'staff']).default('staff'),
});

type Ctx = { params: Promise<{ id: string }> };

export async function GET(request: Request, context: Ctx) {
  return withPlatformAdmin(request, async () => {
    const { id } = await routeParams(context);
    const tenant = await prisma.tenant.findUnique({ where: { id } });
    if (!tenant) return notFound('Barbería no encontrada');

    const users = await prisma.tenantUser.findMany({
      where: { tenantId: tenant.id },
      orderBy: { createdAt: 'desc' },
    });
    return Response.json(users.map(toPublicUser));
  });
}

export async function POST(request: Request, context: Ctx) {
  return withPlatformAdmin(request, async () => {
    const { id } = await routeParams(context);
    const body = await request.json();
    const parsed = createUserSchema.safeParse(body);
    if (!parsed.success) {
      return badRequest(parsed.error.flatten());
    }

    const tenant = await prisma.tenant.findUnique({ where: { id } });
    if (!tenant) return notFound('Barbería no encontrada');

    const exists = await prisma.tenantUser.findUnique({
      where: {
        tenantId_username: { tenantId: tenant.id, username: parsed.data.username },
      },
    });
    if (exists) {
      return Response.json({ error: 'Ese usuario ya existe en esta barbería' }, { status: 409 });
    }

    const user = await prisma.tenantUser.create({
      data: {
        tenantId: tenant.id,
        username: parsed.data.username,
        passwordHash: await bcrypt.hash(parsed.data.password, 10),
        role: parsed.data.role,
      },
    });

    return Response.json(toPublicUser(user), { status: 201 });
  });
}
