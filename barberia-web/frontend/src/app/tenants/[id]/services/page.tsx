'use client';

import Link from 'next/link';
import { useCallback, useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import { AppNav } from '@/components/AppNav';
import { AuthGuard } from '@/components/AuthGuard';
import { EmptyState } from '@/components/EmptyState';
import { LoadingBlock } from '@/components/LoadingBlock';
import { PageHeader } from '@/components/PageHeader';
import { useToast } from '@/components/useToast';
import { api, ApiError, TenantServicesList } from '@/lib/api';

function formatPrice(value: number): string {
  return new Intl.NumberFormat('es-ES', { style: 'currency', currency: 'EUR' }).format(value);
}

export default function TenantServicesPage() {
  const params = useParams();
  const id = params.id as string;
  const { showError } = useToast();

  const [data, setData] = useState<TenantServicesList | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setData(await api.listTenantServices(id));
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Error al cargar servicios';
      showError(msg);
      setData(null);
    } finally {
      setLoading(false);
    }
  }, [id, showError]);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <AuthGuard>
      <AppNav />
      <main className="container">
        <PageHeader
          title={data?.tenantName ?? 'Servicios'}
          subtitle="Catálogo sincronizado desde la app móvil (solo lectura)."
          actions={
            <>
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

        {loading && <LoadingBlock label="Cargando servicios…" />}

        {!loading && data && data.services.length === 0 && (
          <EmptyState
            title="Sin servicios"
            description="Aún no hay servicios en el catálogo. Créalos en la app móvil y sincroniza."
          />
        )}

        {!loading && data && data.services.length > 0 && (
          <div className="card">
            <div style={{ overflowX: 'auto' }}>
              <table className="table">
                <thead>
                  <tr>
                    <th>Nombre</th>
                    <th>Duración</th>
                    <th style={{ textAlign: 'right' }}>Precio</th>
                    <th>Estado</th>
                  </tr>
                </thead>
                <tbody>
                  {data.services.map((service) => (
                    <tr key={service.id}>
                      <td>{service.name}</td>
                      <td>{service.durationMinutes} min</td>
                      <td style={{ textAlign: 'right' }}>{formatPrice(service.price)}</td>
                      <td>
                        <span className={service.active ? 'badge badge-success' : 'badge badge-muted'}>
                          {service.active ? 'Activo' : 'Inactivo'}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        <Link href="/dashboard" className="back-link">
          ← Volver al listado
        </Link>
      </main>
    </AuthGuard>
  );
}
