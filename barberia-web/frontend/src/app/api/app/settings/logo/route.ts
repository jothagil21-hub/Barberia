import { deleteTenantLogo, saveTenantLogo } from '@/lib/server/services/tenant-logo';
import { badRequest, withTenantUser } from '@/lib/server/route-helpers';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  return withTenantUser(request, async (req, user) => {
    const form = await req.formData();
    const file = form.get('file');
    if (!(file instanceof File)) {
      return badRequest('No se envió ningún archivo');
    }

    try {
      const settings = await saveTenantLogo(user.tenantId, file);
      return Response.json({ logoUrl: settings.logoUrl });
    } catch (e) {
      const message = e instanceof Error ? e.message : 'Error al guardar logo';
      return badRequest(message);
    }
  });
}

export async function DELETE(request: Request) {
  return withTenantUser(request, async (_request, user) => {
    await deleteTenantLogo(user.tenantId);
    return Response.json({ logoUrl: null });
  });
}
