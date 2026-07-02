import { deleteTenantLogo, saveTenantLogo } from '@/lib/server/services/tenant-logo';
import { badRequest, withTenantUser } from '@/lib/server/route-helpers';

export const runtime = 'nodejs';

function ownerOnly(role: string) {
  if (role !== 'owner') {
    return badRequest('Solo el owner puede modificar el logo');
  }
  return null;
}

export async function POST(request: Request) {
  return withTenantUser(request, async (req, user) => {
    const denied = ownerOnly(user.role);
    if (denied) return denied;

    const form = await req.formData();
    const file = form.get('file');
    if (!(file instanceof File)) {
      return badRequest('No se envió ningún archivo');
    }

    try {
      const settings = await saveTenantLogo(user.tenantId, file);
      return Response.json({
        logoUrl: settings.logoUrl,
        updatedAt: settings.updatedAt.toISOString(),
      });
    } catch (e) {
      const message = e instanceof Error ? e.message : 'Error al guardar logo';
      return badRequest(message);
    }
  });
}

export async function DELETE(request: Request) {
  return withTenantUser(request, async (_request, user) => {
    const denied = ownerOnly(user.role);
    if (denied) return denied;

    const settings = await deleteTenantLogo(user.tenantId);
    return Response.json({
      logoUrl: null,
      updatedAt: settings.updatedAt.toISOString(),
    });
  });
}
