import { AuthError, jsonError, requirePlatformAdmin } from '@/lib/server/auth-platform';
import { requireTenantUser } from '@/lib/server/auth-app';
import type { TenantJwtPayload } from '@/lib/server/jwt';

export const runtime = 'nodejs';

export async function routeParams<T extends Record<string, string | string[]>>(
  context: { params: Promise<T> },
): Promise<T> {
  return context.params;
}

export async function withPlatformAdmin(
  request: Request,
  handler: (request: Request) => Promise<Response>,
): Promise<Response> {
  try {
    await requirePlatformAdmin(request);
    return await handler(request);
  } catch (error) {
    return jsonError(error);
  }
}

export async function withTenantUser(
  request: Request,
  handler: (request: Request, user: TenantJwtPayload) => Promise<Response>,
): Promise<Response> {
  try {
    const user = await requireTenantUser(request);
    return await handler(request, user);
  } catch (error) {
    return jsonError(error);
  }
}

export function badRequest(message: string | object, status = 400): Response {
  return Response.json(typeof message === 'string' ? { error: message } : message, { status });
}

export function notFound(message: string): Response {
  return Response.json({ error: message }, { status: 404 });
}

export { AuthError };
