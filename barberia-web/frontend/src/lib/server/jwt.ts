import { SignJWT, jwtVerify, type JWTPayload } from 'jose';

export type PlatformJwtPayload = JWTPayload & {
  sub: string;
  username: string;
  type: 'platform_admin';
};

export type TenantJwtPayload = JWTPayload & {
  sub: string;
  username: string;
  tenantId: string;
  role: 'owner' | 'staff';
  type: 'tenant_user';
};

function getSecret() {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET es obligatorio');
  }
  return new TextEncoder().encode(secret);
}

export async function signPlatformToken(payload: {
  sub: string;
  username: string;
}): Promise<string> {
  return new SignJWT({
    sub: payload.sub,
    username: payload.username,
    type: 'platform_admin',
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime('8h')
    .sign(getSecret());
}

export async function verifyPlatformToken(token: string): Promise<PlatformJwtPayload> {
  const { payload } = await jwtVerify(token, getSecret());
  if (payload.type !== 'platform_admin' || typeof payload.sub !== 'string') {
    throw new Error('No autorizado');
  }
  return payload as PlatformJwtPayload;
}

export async function signTenantToken(payload: {
  sub: string;
  username: string;
  tenantId: string;
  role: 'owner' | 'staff';
}): Promise<string> {
  return new SignJWT({
    sub: payload.sub,
    username: payload.username,
    tenantId: payload.tenantId,
    role: payload.role,
    type: 'tenant_user',
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime('7d')
    .sign(getSecret());
}

export async function verifyTenantToken(token: string): Promise<TenantJwtPayload> {
  const { payload } = await jwtVerify(token, getSecret());
  if (payload.type !== 'tenant_user' || typeof payload.sub !== 'string') {
    throw new Error('No autorizado');
  }
  return payload as TenantJwtPayload;
}

export function bearerTokenFromRequest(request: Request): string | null {
  const header = request.headers.get('authorization');
  if (!header?.startsWith('Bearer ')) return null;
  return header.slice('Bearer '.length).trim() || null;
}
