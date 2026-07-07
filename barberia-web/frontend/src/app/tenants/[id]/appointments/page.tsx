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
import { TablePagination } from '@/components/TablePagination';
import { useAutoRefresh } from '@/hooks/useAutoRefresh';
import { useToast } from '@/components/useToast';
import { api, ApiError, TenantAppointmentsDay, TenantPosInvoice } from '@/lib/api';
import { downloadPosInvoicePdf, openPosInvoicePdf } from '@/lib/pos-invoice-pdf';

const DEFAULT_PAGE_SIZE = 10;

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
  pending: 'badge badge-warning',
};

type AppointmentRow = TenantAppointmentsDay['barbers'][number]['appointments'][number] & {
  barberId: string;
  barberName: string;
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
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(DEFAULT_PAGE_SIZE);
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

  useEffect(() => {
    setPage(1);
  }, [date, pageSize]);

  useAutoRefresh(() => load({ silent: true }), [id, date]);

  const allRows = useMemo<AppointmentRow[]>(() => {
    if (!data) return [];
    return data.barbers
      .flatMap((barber) =>
        barber.appointments.map((apt) => ({
          ...apt,
          barberId: barber.id,
          barberName: barber.name,
        })),
      )
      .sort(
        (a, b) =>
          a.time.localeCompare(b.time) || a.barberName.localeCompare(b.barberName),
      );
  }, [data]);

  const totalAppointments = allRows.length;
  const totalPages = Math.max(1, Math.ceil(totalAppointments / pageSize));
  const safePage = Math.min(page, totalPages);

  const paginatedRows = useMemo(
    () => allRows.slice((safePage - 1) * pageSize, safePage * pageSize),
    [allRows, safePage, pageSize],
  );

  useEffect(() => {
    if (page > totalPages) {
      setPage(totalPages);
    }
  }, [page, totalPages]);

  return (
    <AuthGuard>
      <AppNav />
      <main className="container">
        <PageHeader
          title={data?.tenantName ?? 'Citas'}
          subtitle="Agenda del día (solo lectura, sincronizada desde la app)."
          actions={
            <>
              <DatePicker value={date} onChange={setDate} id="appointments-date" />
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

          {!initialLoading && totalAppointments > 0 && (
            <div className="card card-spaced">
              <TablePagination
                page={safePage}
                pageSize={pageSize}
                totalItems={totalAppointments}
                onPageChange={setPage}
                onPageSizeChange={setPageSize}
              />

              <div className="table-scroll">
                <table className="table">
                  <thead>
                    <tr>
                      <th>Hora</th>
                      <th>Barbero</th>
                      <th>Cliente</th>
                      <th>Servicios</th>
                      <th>Estado</th>
                      <th className="text-right">Total</th>
                      <th />
                    </tr>
                  </thead>
                  <tbody>
                    {paginatedRows.map((apt) => (
                      <tr key={apt.id}>
                        <td>{apt.time}</td>
                        <td>{apt.barberName}</td>
                        <td>{apt.clientName}</td>
                        <td>{apt.services.map((s) => s.name).join(', ') || '—'}</td>
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

              <TablePagination
                page={safePage}
                pageSize={pageSize}
                totalItems={totalAppointments}
                onPageChange={setPage}
                onPageSizeChange={setPageSize}
              />
            </div>
          )}
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
