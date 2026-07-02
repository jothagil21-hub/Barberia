import { bearerTokenFromRequest, verifyPlatformToken, type PlatformJwtPayload } from './jwt';

export async function requirePlatformAdmin(
  request: Request,
): Promise<PlatformJwtPayload> {
  const token = bearerTokenFromRequest(request);
  if (!token) {
    throw new AuthError('No autorizado', 401);
  }
  try {
    return await verifyPlatformToken(token);
  } catch {
    throw new AuthError('No autorizado', 401);
  }
}

export class AuthError extends Error {
  constructor(
    message: string,
    public status: number,
  ) {
    super(message);
  }
}

export function jsonError(error: unknown, fallbackStatus = 500): Response {
  if (error instanceof AuthError) {
    return Response.json({ error: error.message }, { status: error.status });
  }
  if (error instanceof Error && error.message === 'JWT_SECRET es obligatorio') {
    return Response.json({ error: 'Configuración del servidor incompleta' }, { status: 500 });
  }
  console.error(error);
  return Response.json({ error: 'Error interno del servidor' }, { status: fallbackStatus });
}
