/**
 * Crea el super-admin inicial (usuario: admin).
 * La contraseña viene de PLATFORM_ADMIN_PASSWORD en .env — nunca en código.
 */
import 'dotenv/config';
import bcrypt from 'bcrypt';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const password = process.env.PLATFORM_ADMIN_PASSWORD;
  if (!password) {
    throw new Error('PLATFORM_ADMIN_PASSWORD es obligatorio en .env para el seed');
  }

  const passwordHash = await bcrypt.hash(password, 10);

  await prisma.platformAdmin.upsert({
    where: { username: 'admin' },
    update: { passwordHash },
    create: { username: 'admin', passwordHash },
  });

  console.log('Super-admin listo (usuario: admin)');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
