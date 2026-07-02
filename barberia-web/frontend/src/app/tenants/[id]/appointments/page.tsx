'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useParams } from 'next/navigation';
import { AppNav } from '@/components/AppNav';
import { AuthGuard } from '@/components/AuthGuard';
import { EmptyState } from '@/components/EmptyState';
import { LoadingBlock } from '@/components/LoadingBlock';
import { PageHeader } from '@/components/PageHeader';
import { useAutoRefresh } from '@/hooks/useAutoRefresh';
import { useToast } from '@/components/useToast';
import { api, ApiError, TenantAppointmentsDay, TenantPosInvoice } from '@/lib/api';
import { downloadPosInvoicePdf, openPosInvoicePdf } from '@/lib/pos-invoice-pdf';

function todayIso(): string {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function formatPrice(value: number): string {
  return new Intl.NumberFormat('es-ES', { style: 'currency', currency: 'EUR' }).format(value);
}

const STATUS_CLASS: Record<string, string> = {
  scheduled: 'badge badge-neutral',
  attended: 'badge badge-success',
  canceled: 'badge badge-muted',
  no_show: 'badge badge-warning',
};

function InvoiceLink({
  tenantId,
  appointmentId,
  onShow,
}: {
  tenantId: string;
  appointmentId: string;
  onShow: (invoice: TenantPosInvoice) => void;
}) {
  const [loading, setLoading] = useState(false);

  return (
    <button
      type="button"
      className="btn btn-secondary"
      style={{ padding: '0.25rem 0.5rem', fontSize: '0.85rem' }}
      disabled={loading}
      onClick={() => {
        setLoading(true);
        void api
          .getTenantInvoiceByAppointment(tenantId, appointmentId)
          .then(onShow)
          .catch(() => alert('Comprobante no disponible'))
          .finally(() => setLoading(false));
      }}
    >
      {loading ? '…' : 'Comprobante'}
    </button>
  );
}

export default function TenantAppointmentsPage() {
  const params = useParams();
  const id = params.id as string;
  const { showError } = useToast();

  const [date, setDate] = useState(todayIso);
  const [data, setData] = useState<TenantAppointmentsDay | null>(null);
  const [loading, setLoading] = useState(true);
  const [invoiceModal, setInvoiceModal] = useState<TenantPosInvoice | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  const load = useCallback(
    async (options?: { silent?: boolean }) => {
      const silent = options?.silent ?? false;
      abortRef.current?.abort();
      const controller = new AbortController();
      abortRef.current = controller;

      if (!silent) setLoading(true);
      try {
        const result = await api.getTenantAppointments(id, date);
        if (!controller.signal.aborted) {
          setData(result);
        }
      } catch (err) {
        if (controller.signal.aborted) return;
        const msg = err instanceof ApiError ? err.message : 'Error al cargar citas';
        if (!silent) {
          showError(msg);
          setData(null);
        }
      } finally {
        if (!controller.signal.aborted && !silent) {
          setLoading(false);
        }
      }
    },
    [id, date, showError],
  );

  useEffect(() => {
    void load();
  }, [load]);

  useAutoRefresh(() => load({ silent: true }), [id, date]);

  const totalAppointments = useMemo(
    () => data?.barbers.reduce((sum, b) => sum + b.appointments.length, 0) ?? 0,
    [data],
  );

  return (
    <AuthGuard>
      <AppNav />
      <main className="container">
        <PageHeader
          title={data?.tenantName ?? 'Citas'}
          subtitle="Agenda del día por barbero (solo lectura, sincronizada desde la app)."
          actions={
            <>
              <label style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <span className="muted">Fecha</span>
                <input
                  type="date"
                  value={date}
                  onChange={(e) => setDate(e.target.value)}
                  aria-label="Fecha"
                />
              </label>
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => void load()}
                disabled={loading}
              >
                Actualizar
              </button>
              <Link href={`/tenants/${id}`} className="btn btn-secondary">
                Volver al detalle
              </Link>
            </>
          }
        />

        {loading && <LoadingBlock label="Cargando citas…" />}

        {!loading && data && totalAppointments === 0 && (
          <EmptyState
            title="Sin citas este día"
            description="No hay citas programadas para la fecha seleccionada. Las citas aparecen aquí cuando la app móvil las sincroniza."
          />
        )}

        {!loading &&
          data?.barbers.map((barber) => (
            <div key={barber.id} className="card" style={{ marginBottom: '1rem' }}>
              <h2>{barber.name}</h2>
              {barber.appointments.length === 0 ? (
                <p className="muted">Sin citas</p>
              ) : (
                <div style={{ overflowX: 'auto' }}>
                  <table className="table">
                    <thead>
                      <tr>
                        <th>Hora</th>
                        <th>Cliente</th>
                        <th>Servicios</th>
                        <th>Estado</th>
                        <th style={{ textAlign: 'right' }}>Total</th>
                        <th />
                      </tr>
                    </thead>
                    <tbody>
                      {barber.appointments.map((apt) => (
                        <tr key={apt.id}>
                          <td>{apt.time}</td>
                          <td>{apt.clientName}</td>
                          <td>
                            {apt.services.map((s) => s.name).join(', ') || '—'}
                          </td>
                          <td>
                            <span className={STATUS_CLASS[apt.status] ?? 'badge'}>
                              {apt.statusLabel}
                            </span>
                          </td>
                          <td style={{ textAlign: 'right' }}>{formatPrice(apt.totalPrice)}</td>
                          <td>
                            {apt.status === 'attended' ? (
                              <InvoiceLink
                                tenantId={id}
                                appointmentId={apt.id}
                                onShow={setInvoiceModal}
                              />
                            ) : (
                              '—'
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          ))}

        <Link href="/dashboard" className="back-link">
          ← Volver al listado
        </Link>

        {invoiceModal && (
          <div
            role="dialog"
            aria-modal="true"
            style={{
              position: 'fixed',
              inset: 0,
              background: 'rgba(0,0,0,0.45)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '1rem',
              zIndex: 50,
            }}
            onClick={() => setInvoiceModal(null)}
          >
            <div
              className="card"
              style={{ maxWidth: 520, width: '100%' }}
              onClick={(e) => e.stopPropagation()}
            >
              <h2>Comprobante #{invoiceModal.number}</h2>
              <p className="muted">
                {new Date(invoiceModal.issuedAt).toLocaleString('es-ES')}
              </p>
              <p>
                <strong>Cliente:</strong> {invoiceModal.clientName}
              </p>
              {invoiceModal.barberName && (
                <p>
                  <strong>Barbero:</strong> {invoiceModal.barberName}
                </p>
              )}
              <table className="table" style={{ marginTop: '1rem' }}>
                <thead>
                  <tr>
                    <th>Servicio</th>
                    <th>Duración</th>
                    <th style={{ textAlign: 'right' }}>Precio</th>
                  </tr>
                </thead>
                <tbody>
                  {invoiceModal.lines.map((line, index) => (
                    <tr key={`${line.serviceName}-${index}`}>
                      <td>{line.serviceName}</td>
                      <td>{line.durationMinutes} min</td>
                      <td style={{ textAlign: 'right' }}>{formatPrice(line.lineTotal)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <p style={{ textAlign: 'right', fontWeight: 600, marginTop: '1rem' }}>
                Total: {formatPrice(invoiceModal.subtotal)}
              </p>
              <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', marginTop: '1rem' }}>
                <button
                  type="button"
                  className="btn btn-primary"
                  onClick={() =>
                    openPosInvoicePdf(invoiceModal, data?.tenantName ?? 'Barbería')
                  }
                >
                  Ver PDF
                </button>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() =>
                    downloadPosInvoicePdf(invoiceModal, data?.tenantName ?? 'Barbería')
                  }
                >
                  Descargar PDF
                </button>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setInvoiceModal(null)}
                >
                  Cerrar
                </button>
              </div>
            </div>
          </div>
        )}
      </main>
    </AuthGuard>
  );
}
