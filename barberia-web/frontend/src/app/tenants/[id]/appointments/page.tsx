'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useParams } from 'next/navigation';
import { AppNav } from '@/components/AppNav';
import { AuthGuard } from '@/components/AuthGuard';
import { DatePicker } from '@/components/DatePicker';
import { EmptyState } from '@/components/EmptyState';
import { InlineSpinner } from '@/components/InlineSpinner';
import { LoadingBlock } from '@/components/LoadingBlock';
import { LoadingButton } from '@/components/LoadingButton';
import { Modal } from '@/components/Modal';
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
  onError,
}: {
  tenantId: string;
  appointmentId: string;
  onShow: (invoice: TenantPosInvoice) => void;
  onError: (message: string) => void;
}) {
  const [loading, setLoading] = useState(false);

  return (
    <LoadingButton
      variant="secondary"
      className="btn-compact"
      loading={loading}
      loadingText="…"
      onClick={() => {
        setLoading(true);
        void api
          .getTenantInvoiceByAppointment(tenantId, appointmentId)
          .then(onShow)
          .catch(() => onError('Comprobante no disponible'))
          .finally(() => setLoading(false));
      }}
    >
      Comprobante
    </LoadingButton>
  );
}

export default function TenantAppointmentsPage() {
  const params = useParams();
  const id = params.id as string;
  const { showError } = useToast();

  const [date, setDate] = useState(todayIso);
  const [data, setData] = useState<TenantAppointmentsDay | null>(null);
  const [initialLoading, setInitialLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [invoiceModal, setInvoiceModal] = useState<TenantPosInvoice | null>(null);
  const abortRef = useRef<AbortController | null>(null);
  const hasLoadedRef = useRef(false);

  const load = useCallback(
    async (options?: { silent?: boolean }) => {
      const silent = options?.silent ?? false;
      abortRef.current?.abort();
      const controller = new AbortController();
      abortRef.current = controller;

      if (!silent) {
        if (!hasLoadedRef.current) setInitialLoading(true);
        else setRefreshing(true);
      }
      try {
        const result = await api.getTenantAppointments(id, date);
        if (!controller.signal.aborted) {
          setData(result);
          hasLoadedRef.current = true;
        }
      } catch (err) {
        if (controller.signal.aborted) return;
        const msg = err instanceof ApiError ? err.message : 'Error al cargar citas';
        if (!silent) {
          showError(msg);
          if (!hasLoadedRef.current) setData(null);
        }
      } finally {
        if (!controller.signal.aborted && !silent) {
          setInitialLoading(false);
          setRefreshing(false);
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
              <DatePicker value={date} onChange={setDate} />
              <LoadingButton
                variant="secondary"
                loading={refreshing}
                loadingText="Actualizando…"
                disabled={initialLoading}
                onClick={() => void load()}
              >
                Actualizar
              </LoadingButton>
              <Link href={`/tenants/${id}`} className="btn btn-secondary">
                Volver al detalle
              </Link>
            </>
          }
        />

        {initialLoading && <LoadingBlock label="Cargando citas…" />}

        <div className={`page-content${refreshing ? ' page-content-refreshing' : ''}`}>
          {!initialLoading && refreshing && (
            <div className="refresh-note">
              <InlineSpinner label="Actualizando citas…" />
            </div>
          )}

        {!initialLoading && data && totalAppointments === 0 && (
          <EmptyState
            title="Sin citas este día"
            description="No hay citas programadas para la fecha seleccionada. Las citas aparecen aquí cuando la app móvil las sincroniza."
          />
        )}

        {!initialLoading &&
          data?.barbers.map((barber) => (
            <div key={barber.id} className="card card-spaced">
              <h2>{barber.name}</h2>
              {barber.appointments.length === 0 ? (
                <p className="muted">Sin citas</p>
              ) : (
                <div className="table-scroll">
                  <table className="table">
                    <thead>
                      <tr>
                        <th>Hora</th>
                        <th>Cliente</th>
                        <th>Servicios</th>
                        <th>Estado</th>
                        <th className="text-right">Total</th>
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
                          <td className="text-right">{formatPrice(apt.totalPrice)}</td>
                          <td>
                            {apt.status === 'attended' ? (
                              <InvoiceLink
                                tenantId={id}
                                appointmentId={apt.id}
                                onShow={setInvoiceModal}
                                onError={showError}
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

        </div>

        <Link href="/dashboard" className="back-link">
          ← Volver al listado
        </Link>

        <Modal
          open={invoiceModal !== null}
          onClose={() => setInvoiceModal(null)}
          title={invoiceModal ? `Comprobante #${invoiceModal.number}` : ''}
          footer={
            invoiceModal ? (
              <div className="modal-actions">
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
            ) : undefined
          }
        >
          {invoiceModal && (
            <>
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
              <table className="table modal-table">
                <thead>
                  <tr>
                    <th>Servicio</th>
                    <th>Duración</th>
                    <th className="text-right">Precio</th>
                  </tr>
                </thead>
                <tbody>
                  {invoiceModal.lines.map((line, index) => (
                    <tr key={`${line.serviceName}-${index}`}>
                      <td>{line.serviceName}</td>
                      <td>{line.durationMinutes} min</td>
                      <td className="text-right">{formatPrice(line.lineTotal)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <p className="modal-total">Total: {formatPrice(invoiceModal.subtotal)}</p>
            </>
          )}
        </Modal>
      </main>
    </AuthGuard>
  );
}
