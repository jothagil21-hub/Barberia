import type { TenantUserRole } from '@prisma/client';
import type { SyncConflict } from '@/lib/server/services/sync/types';

export type SyncActor = {
  userId: string;
  role: TenantUserRole;
  barberId: string | null;
};

export const STAFF_FORBIDDEN_MSG = 'No tienes permiso para esta acción (solo owner)';

export const STAFF_BARBER_SCOPE_MSG =
  'Solo puedes gestionar citas de tu barbero asignado';

export function isStaff(actor: SyncActor): boolean {
  return actor.role === 'staff';
}

export function staffForbiddenConflict(
  entity: SyncConflict['entity'],
  clientId?: string,
  serverId?: string,
): SyncConflict {
  return {
    entity,
    ...(clientId ? { clientId } : {}),
    ...(serverId ? { serverId } : {}),
    reason: STAFF_FORBIDDEN_MSG,
  };
}

export function staffBarberScopeConflict(
  clientId?: string,
  serverId?: string,
): SyncConflict {
  return {
    entity: 'appointment',
    ...(clientId ? { clientId } : {}),
    ...(serverId ? { serverId } : {}),
    reason: STAFF_BARBER_SCOPE_MSG,
  };
}

export async function loadSyncActor(userId: string): Promise<SyncActor | null> {
  const { prisma } = await import('@/lib/server/prisma');
  const user = await prisma.tenantUser.findUnique({
    where: { id: userId },
    select: { role: true, barberId: true, active: true },
  });
  if (!user || !user.active) return null;
  return { userId, role: user.role, barberId: user.barberId };
}
