/**
 * Cliente HTTP hacia el backend.
 * Todas las funciones devuelven JSON o lanzan ApiError con mensaje legible.
 */
import { getToken } from './auth';

/** URL base del API. Vacío = mismo origen (Next.js / Vercel). */
export function getApiBaseUrl(): string {
  const configured = process.env.NEXT_PUBLIC_API_URL;
  if (configured && configured.trim() !== '') {
    return configured.replace(/\/$/, '');
  }
  if (typeof window !== 'undefined') {
    return '';
  }
  if (process.env.VERCEL_URL) {
    return `https://${process.env.VERCEL_URL}`;
  }
  return 'http://localhost:3000';
}

export type Tenant = {
  id: string;
  name: string;
  slug: string;
  active: boolean;
  createdAt: string;
  updatedAt: string;
  settings: TenantSettings | null;
  userCount: number;
};

export type TenantSettings = {
  id: string;
  tenantId: string;
  displayName: string;
  logoUrl: string | null;
  scheduleStart: string;
  scheduleEnd: string;
  scheduleInterval: number;
};

export type TenantUser = {
  id: string;
  username: string;
  role: 'owner' | 'staff';
  active: boolean;
  barberId: string | null;
  createdAt: string;
  updatedAt: string;
};

export type TenantBarber = {
  id: string;
  name: string;
  active: boolean;
  updatedAt: string;
};

export type AppointmentServiceLine = {
  name: string;
  unitPrice: number;
  durationMinutes?: number;
};

export type TenantAppointment = {
  id: string;
  clientName: string;
  time: string;
  durationMinutes?: number;
  status: string;
  statusLabel: string;
  services: AppointmentServiceLine[];
  totalPrice: number;
};

export type BarberAppointments = {
  id: string;
  name: string;
  active: boolean;
  appointments: TenantAppointment[];
};

export type TenantAppointmentsDay = {
  date: string;
  tenantName: string;
  barbers: BarberAppointments[];
};

export type PosInvoiceLine = {
  serviceName: string;
  durationMinutes: number;
  unitPrice: number;
  lineTotal: number;
};

export type TenantPosInvoice = {
  id: string;
  appointmentId: string;
  number: number;
  issuedAt: string;
  clientName: string;
  barberName: string | null;
  subtotal: number;
  lines: PosInvoiceLine[];
  appointmentDate?: string;
  appointmentTime?: string;
};

export type TenantService = {
  id: string;
  name: string;
  price: number;
  durationMinutes: number;
  active: boolean;
  updatedAt: string;
};

export type TenantServicesList = {
  tenantName: string;
  services: TenantService[];
};

export class ApiError extends Error {
  constructor(message: string, public status: number) {
    super(message);
  }
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const headers = new Headers(options.headers);
  const token = getToken();
  if (token) headers.set('Authorization', `Bearer ${token}`);
  if (options.body && !(options.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }

  const res = await fetch(`${getApiBaseUrl()}${path}`, { ...options, headers });
  if (!res.ok) {
    let message = res.statusText;
    try {
      const data = await res.json();
      if (data.error) {
        message = typeof data.error === 'string' ? data.error : JSON.stringify(data.error);
      }
    } catch {
      /* sin cuerpo JSON */
    }
    throw new ApiError(message, res.status);
  }
  return res.json() as Promise<T>;
}

export const api = {
  login: (username: string, password: string) =>
    request<{ token: string; username: string }>('/api/platform/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    }),

  listTenants: () => request<Tenant[]>('/api/platform/tenants'),

  getTenant: (id: string) => request<Tenant>(`/api/platform/tenants/${id}`),

  createTenant: (data: { name: string; slug?: string }) =>
    request<Tenant>('/api/platform/tenants', {
      method: 'POST',
      body: JSON.stringify(data),
    }),

  patchTenant: (id: string, data: { name?: string; active?: boolean }) =>
    request<Tenant>(`/api/platform/tenants/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(data),
    }),

  updateSettings: (id: string, data: Partial<TenantSettings>) =>
    request<TenantSettings>(`/api/platform/tenants/${id}/settings`, {
      method: 'PUT',
      body: JSON.stringify({
        displayName: data.displayName,
        logoUrl: data.logoUrl,
        scheduleStart: data.scheduleStart,
        scheduleEnd: data.scheduleEnd,
        scheduleInterval: data.scheduleInterval,
      }),
    }),

  uploadLogo: (id: string, file: File) => {
    const form = new FormData();
    form.append('file', file);
    return request<TenantSettings>(`/api/platform/tenants/${id}/logo`, {
      method: 'POST',
      body: form,
    });
  },

  listUsers: (tenantId: string) =>
    request<TenantUser[]>(`/api/platform/tenants/${tenantId}/users`),

  listBarbers: (tenantId: string) =>
    request<{ barbers: TenantBarber[] }>(`/api/platform/tenants/${tenantId}/barbers`),

  createUser: (
    tenantId: string,
    data: {
      username: string;
      password: string;
      role: 'owner' | 'staff';
      barberId?: string | null;
    },
  ) =>
    request<TenantUser>(`/api/platform/tenants/${tenantId}/users`, {
      method: 'POST',
      body: JSON.stringify(data),
    }),

  patchUser: (
    tenantId: string,
    userId: string,
    data: {
      active?: boolean;
      role?: 'owner' | 'staff';
      password?: string;
      barberId?: string | null;
    },
  ) =>
    request<TenantUser>(`/api/platform/tenants/${tenantId}/users/${userId}`, {
      method: 'PATCH',
      body: JSON.stringify(data),
    }),

  getTenantAppointments: (tenantId: string, date: string) =>
    request<TenantAppointmentsDay>(
      `/api/platform/tenants/${tenantId}/appointments?date=${encodeURIComponent(date)}`,
    ),

  getTenantInvoiceByAppointment: (tenantId: string, appointmentId: string) =>
    request<TenantPosInvoice>(
      `/api/platform/tenants/${tenantId}/invoices/by-appointment/${appointmentId}`,
    ),

  getTenantInvoice: (tenantId: string, invoiceId: string) =>
    request<TenantPosInvoice>(`/api/platform/tenants/${tenantId}/invoices/${invoiceId}`),

  listTenantServices: (tenantId: string) =>
    request<TenantServicesList>(`/api/platform/tenants/${tenantId}/services`),
};

export function logoSrc(logoUrl: string | null | undefined): string | null {
  if (!logoUrl) return null;
  if (logoUrl.startsWith('http')) return logoUrl;
  const base = getApiBaseUrl();
  return base ? `${base}${logoUrl}` : logoUrl;
}
