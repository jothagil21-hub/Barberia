import { Prisma } from '@prisma/client';

export const tenantSelect = {
  id: true,
  name: true,
  slug: true,
  active: true,
  createdAt: true,
  updatedAt: true,
  settings: true,
  _count: { select: { users: true } },
} satisfies Prisma.TenantSelect;

export type TenantRow = Prisma.TenantGetPayload<{ select: typeof tenantSelect }>;

export function formatTenant(t: TenantRow) {
  return {
    id: t.id,
    name: t.name,
    slug: t.slug,
    active: t.active,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
    settings: t.settings,
    userCount: t._count.users,
  };
}

export function toPublicUser(user: {
  id: string;
  username: string;
  role: string;
  active: boolean;
  barberId?: string | null;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: user.id,
    username: user.username,
    role: user.role,
    active: user.active,
    barberId: user.barberId ?? null,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

export const STATUS_LABELS: Record<string, string> = {
  scheduled: 'Programada',
  canceled: 'Cancelada',
  attended: 'Asistió',
  no_show: 'No asistió',
};
