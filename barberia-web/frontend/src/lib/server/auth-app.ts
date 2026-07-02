import { bearerTokenFromRequest, verifyTenantToken, type TenantJwtPayload } from '@/lib/server/jwt';
import { AuthError } from '@/lib/server/auth-platform';

export async function requireTenantUser(request: Request): Promise<TenantJwtPayload> {
  const token = bearerTokenFromRequest(request);
  if (!token) {
    throw new AuthError('No autorizado', 401);
  }
  try {
    return await verifyTenantToken(token);
  } catch {
    throw new AuthError('No autorizado', 401);
  }
}
