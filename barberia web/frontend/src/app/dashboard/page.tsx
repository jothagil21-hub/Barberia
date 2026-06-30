'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { AppNav } from '@/components/AppNav';
import { AuthGuard } from '@/components/AuthGuard';
import { EmptyState } from '@/components/EmptyState';
import { LoadingBlock } from '@/components/LoadingBlock';
import { PageHeader } from '@/components/PageHeader';
import { useToast } from '@/components/useToast';
import { api, ApiError, Tenant } from '@/lib/api';

export default function DashboardPage() {
  const { showError } = useToast();
  const [tenants, setTenants] = useState<Tenant[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.listTenants()
      .then(setTenants)
      .catch((err) => {
        const msg = err instanceof ApiError ? err.message : 'Error al cargar barberías';
        showError(msg);
      })
      .finally(() => setLoading(false));
  }, [showError]);

  return (
    <AuthGuard>
      <AppNav />
      <main className="container">
        <PageHeader
          title="Barberías"
          subtitle="Gestiona los negocios registrados en la plataforma."
          actions={<Link href="/tenants/new" className="btn btn-primary">Nueva barbería</Link>}
        />

        {loading ? (
          <LoadingBlock label="Cargando barberías…" />
        ) : tenants.length === 0 ? (
          <EmptyState
            title="Aún no hay barberías"
            description="Crea la primera barbería para empezar a configurar branding y usuarios de app."
            action={<Link href="/tenants/new" className="btn btn-primary">Crear barbería</Link>}
          />
        ) : (
          <div className="card card-table">
            <table className="table">
              <thead>
                <tr>
                  <th>Nombre</th>
                  <th>Slug</th>
                  <th>Estado</th>
                  <th>Usuarios</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {tenants.map((t) => (
                  <tr key={t.id}>
                    <td>{t.name}</td>
                    <td className="muted">{t.slug}</td>
                    <td>
                      <span className={t.active ? 'badge badge-active' : 'badge badge-inactive'}>
                        {t.active ? 'Activa' : 'Inactiva'}
                      </span>
                    </td>
                    <td>{t.userCount}</td>
                    <td><Link href={`/tenants/${t.id}`}>Gestionar</Link></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </main>
    </AuthGuard>
  );
}
