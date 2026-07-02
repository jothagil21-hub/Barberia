import bcrypt from 'bcrypt';
import { z } from 'zod';
import { prisma } from '@/lib/server/prisma';
import { signTenantToken } from '@/lib/server/jwt';
import { badRequest } from '@/lib/server/route-helpers';

export const runtime = 'nodejs';

const loginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
});

export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return badRequest('Datos de login inválidos');
  }

  const parsed = loginSchema.safeParse(body);
  if (!parsed.success) {
    return badRequest('Datos de login inválidos');
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
    return Response.json({ error: 'Usuario o contraseña incorrectos' }, { status: 401 });
  }

  if (user.role === 'staff' && !user.barberId) {
    return Response.json(
      { error: 'Usuario staff sin barbero asignado. Contacta al administrador del panel.' },
      { status: 403 },
    );
  }

  const token = await signTenantToken({
    sub: user.id,
    username: user.username,
    tenantId: user.tenantId,
    role: user.role,
  });

  return Response.json({
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
      barberId: user.barberId,
    },
  });
}
