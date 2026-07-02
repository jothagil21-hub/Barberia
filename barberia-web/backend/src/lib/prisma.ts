import { PrismaClient } from '@prisma/client';

/** Cliente único de base de datos (Prisma). */
export const prisma = new PrismaClient();
