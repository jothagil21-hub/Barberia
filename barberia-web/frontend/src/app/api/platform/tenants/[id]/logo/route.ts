import { prisma } from '@/lib/server/prisma';
import { saveTenantLogo } from '@/lib/server/services/tenant-logo';
import { badRequest, notFound, routeParams, withPlatformAdmin } from '@/lib/server/route-helpers';

export const runtime = 'nodejs';

type Ctx = { params: Promise<{ id: string }> };

export async function POST(request: Request, context: Ctx) {
  return withPlatformAdmin(request, async () => {
    const { id } = await routeParams(context);
    const tenant = await prisma.tenant.findUnique({ where: { id } });
    if (!tenant) return notFound('Barbería no encontrada');

    const form = await request.formData();
    const file = form.get('file');
    if (!(file instanceof File)) {
      return badRequest('No se envió ningún archivo');
    }

    try {
      const settings = await saveTenantLogo(tenant.id, file);
      return Response.json(settings);
    } catch (e) {
      const message = e instanceof Error ? e.message : 'Error al guardar logo';
      return badRequest(message);
    }
  });
}
