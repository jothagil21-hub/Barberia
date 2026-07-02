import bcrypt from 'bcrypt';
import { z } from 'zod';
import { jsonError } from '@/lib/server/auth-platform';
import { signPlatformToken } from '@/lib/server/jwt';
import { prisma } from '@/lib/server/prisma';

export const runtime = 'nodejs';

const loginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
});

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const parsed = loginSchema.safeParse(body);
    if (!parsed.success) {
      return Response.json({ error: 'Datos de login inválidos' }, { status: 400 });
    }

    const { username, password } = parsed.data;
    const admin = await prisma.platformAdmin.findUnique({ where: { username } });
    if (!admin || !(await bcrypt.compare(password, admin.passwordHash))) {
      return Response.json({ error: 'Usuario o contraseña incorrectos' }, { status: 401 });
    }

    const token = await signPlatformToken({
      sub: admin.id,
      username: admin.username,
    });

    return Response.json({ token, username: admin.username });
  } catch (error) {
    return jsonError(error);
  }
}
