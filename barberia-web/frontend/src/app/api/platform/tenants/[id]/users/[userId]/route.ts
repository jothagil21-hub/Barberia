import bcrypt from 'bcrypt';
import { z } from 'zod';
import { prisma } from '@/lib/server/prisma';
import { badRequest, notFound, routeParams, withPlatformAdmin } from '@/lib/server/route-helpers';
import { toPublicUser } from '@/lib/server/tenants/format';

export const runtime = 'nodejs';

const patchUserSchema = z.object({
  active: z.boolean().optional(),
  role: z.enum(['owner', 'staff']).optional(),
  password: z.string().min(4).max(120).optional(),
});

type Ctx = { params: Promise<{ id: string; userId: string }> };

export async function PATCH(request: Request, context: Ctx) {
  return withPlatformAdmin(request, async () => {
    const { id, userId } = await routeParams(context);
    const body = await request.json();
    const parsed = patchUserSchema.safeParse(body);
    if (!parsed.success) {
      return badRequest(parsed.error.flatten());
    }

    const user = await prisma.tenantUser.findFirst({
      where: { id: userId, tenantId: id },
    });
    if (!user) return notFound('Usuario no encontrado');

    const data: { active?: boolean; role?: 'owner' | 'staff'; passwordHash?: string } = {};
    if (parsed.data.active !== undefined) data.active = parsed.data.active;
    if (parsed.data.role !== undefined) data.role = parsed.data.role;
    if (parsed.data.password) {
      data.passwordHash = await bcrypt.hash(parsed.data.password, 10);
    }

    const updated = await prisma.tenantUser.update({ where: { id: user.id }, data });
    return Response.json(toPublicUser(updated));
  });
}
