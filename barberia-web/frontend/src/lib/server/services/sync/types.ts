export type SyncServiceLine = {
  serviceId: string;
  unitPrice: number;
  durationMinutes: number;
};

export type PosInvoiceLine = {
  serviceName: string;
  durationMinutes: number;
  unitPrice: number;
  lineTotal: number;
};

export type SyncBarber = {
  id: string;
  name: string;
  active: boolean;
  updatedAt: string;
};

export type SyncService = {
  id: string;
  name: string;
  price: number;
  durationMinutes: number;
  active: boolean;
  updatedAt: string;
};

export type SyncAppointment = {
  id: string;
  barberId: string;
  clientName: string;
  clientPhone: string | null;
  source: string;
  date: string;
  time: string;
  durationMinutes: number;
  status: string;
  createdAt: string;
  canceledAt: string | null;
  pendingExpiresAt: string | null;
  updatedAt: string;
  services: SyncServiceLine[];
};

export type SyncPosInvoice = {
  id: string;
  appointmentId: string;
  number: number;
  issuedAt: string;
  clientName: string;
  barberName: string | null;
  subtotal: number;
  lines: PosInvoiceLine[];
  updatedAt: string;
};

export type SyncScheduleBlock = {
  id: string;
  barberId: string;
  date: string;
  time: string | null;
  isFullDay: boolean;
  createdAt: string;
  updatedAt: string;
};

export type SyncSettings = {
  shopName: string;
  displayName: string;
  logoUrl: string | null;
  scheduleStart: string;
  scheduleEnd: string;
  scheduleInterval: number;
  updatedAt: string;
};

export type SyncEntitySnapshots = {
  barbers: string[];
  services: string[];
  appointments: string[];
  scheduleBlocks: string[];
  posInvoices: string[];
};

export type SyncPullBundle = {
  serverTime: string;
  settings: SyncSettings;
  barbers: SyncBarber[];
  services: SyncService[];
  appointments: SyncAppointment[];
  scheduleBlocks: SyncScheduleBlock[];
  posInvoices: SyncPosInvoice[];
  snapshots: SyncEntitySnapshots;
};

export type UpsertBarber = {
  id?: string;
  clientId?: string;
  name: string;
  active: boolean;
  updatedAt: string;
};

export type UpsertService = {
  id?: string;
  clientId?: string;
  name: string;
  price: number;
  durationMinutes: number;
  active: boolean;
  updatedAt: string;
};

export type UpsertAppointment = {
  id?: string;
  clientId?: string;
  barberId: string;
  clientName: string;
  clientPhone?: string | null;
  date: string;
  time: string;
  durationMinutes: number;
  status: string;
  createdAt?: string;
  canceledAt?: string | null;
  updatedAt: string;
  services: SyncServiceLine[];
};

export type UpsertPosInvoice = {
  id?: string;
  clientId?: string;
  appointmentId: string;
  number: number;
  issuedAt: string;
  clientName: string;
  barberName?: string | null;
  subtotal: number;
  lines: PosInvoiceLine[];
  updatedAt: string;
};

export type UpsertScheduleBlock = {
  id?: string;
  clientId?: string;
  barberId: string;
  date: string;
  time?: string | null;
  isFullDay: boolean;
  createdAt?: string;
  updatedAt: string;
};

export type SyncChanges = {
  barbers?: UpsertBarber[];
  services?: UpsertService[];
  appointments?: UpsertAppointment[];
  scheduleBlocks?: UpsertScheduleBlock[];
  posInvoices?: UpsertPosInvoice[];
  settings?: Partial<{
    shopName: string;
    displayName: string;
    scheduleStart: string;
    scheduleEnd: string;
    scheduleInterval: number;
    updatedAt: string;
  }>;
};

export type SyncConflict = {
  entity: 'appointment' | 'barber' | 'service' | 'scheduleBlock' | 'settings' | 'posInvoice';
  clientId?: string;
  serverId?: string;
  reason: string;
};

export type AppliedIds = {
  barbers: Record<string, string>;
  services: Record<string, string>;
  appointments: Record<string, string>;
  scheduleBlocks: Record<string, string>;
  posInvoices: Record<string, string>;
};

export type SyncPostResult = {
  serverTime: string;
  applied: AppliedIds;
  conflicts: SyncConflict[];
  pull: SyncPullBundle;
};
