import { prisma } from '@/lib/server/prisma';

export async function assertActiveBarberForTenant(tenantId: string, barberId: string) {
  const barber = await prisma.barber.findFirst({
    where: { id: barberId, tenantId, active: true },
  });
  if (!barber) {
    throw new Error('Barbero no válido o inactivo para esta barbería');
  }
  return barber;
}
