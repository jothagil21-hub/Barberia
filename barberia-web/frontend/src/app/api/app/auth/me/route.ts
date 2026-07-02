import { prisma } from '@/lib/server/prisma';
import { withTenantUser } from '@/lib/server/route-helpers';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  return withTenantUser(request, async (_request, payload) => {
    const user = await prisma.tenantUser.findUnique({
      where: { id: payload.sub },
      include: { tenant: { include: { settings: true } } },
    });

    if (!user || !user.active || !user.tenant.active) {
      return Response.json({ error: 'Sesión inválida' }, { status: 401 });
    }

    return Response.json({
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
    });
  });
}
