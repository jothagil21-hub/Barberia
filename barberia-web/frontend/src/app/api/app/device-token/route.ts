import { z } from 'zod';
import { registerDeviceToken } from '@/lib/server/services/notifications/fcm';
import { badRequest, withTenantUser } from '@/lib/server/route-helpers';

export const runtime = 'nodejs';

const bodySchema = z.object({
  fcmToken: z.string().min(1),
  platform: z.enum(['android', 'ios']),
});

export async function POST(request: Request) {
  return withTenantUser(request, async (req, user) => {
    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return badRequest('Cuerpo JSON inválido');
    }

    const parsed = bodySchema.safeParse(body);
    if (!parsed.success) {
      return badRequest(parsed.error.flatten());
    }

    await registerDeviceToken({
      tenantUserId: user.sub,
      fcmToken: parsed.data.fcmToken,
      platform: parsed.data.platform,
    });

    return Response.json({ ok: true });
  });
}
