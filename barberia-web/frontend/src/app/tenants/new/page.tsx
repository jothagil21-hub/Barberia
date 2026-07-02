'use client';

import Link from 'next/link';
import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { AppNav } from '@/components/AppNav';
import { AuthGuard } from '@/components/AuthGuard';
import { InlineAlert } from '@/components/InlineAlert';
import { LoadingButton } from '@/components/LoadingButton';
import { PageHeader } from '@/components/PageHeader';
import { useToast } from '@/components/useToast';
import { api, ApiError } from '@/lib/api';

export default function NewTenantPage() {
  const router = useRouter();
  const { showSuccess, showError } = useToast();
  const [name, setName] = useState('');
  const [slug, setSlug] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const tenant = await api.createTenant({ name, slug: slug.trim() || undefined });
      showSuccess('Barbería creada correctamente');
      router.replace(`/tenants/${tenant.id}`);
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'No se pudo crear la barbería';
      setError(msg);
      showError(`No se pudo crear: ${msg}`);
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthGuard>
      <AppNav />
      <main className="container">
        <PageHeader title="Nueva barbería" subtitle="Registra un nuevo negocio en la plataforma." />
        <div className="card form-card">
          <form onSubmit={onSubmit}>
            <div className="field">
              <label htmlFor="name">Nombre del negocio</label>
              <input id="name" value={name} onChange={(e) => setName(e.target.value)} required />
            </div>
            <div className="field">
              <label htmlFor="slug">Slug (opcional)</label>
              <input id="slug" value={slug} onChange={(e) => setSlug(e.target.value)} placeholder="mi-barberia" />
            </div>
            {error && <InlineAlert message={error} />}
            <div className="actions-row actions-row-flush">
              <LoadingButton type="submit" loading={loading} loadingText="Creando…">
                Crear
              </LoadingButton>
              <Link href="/dashboard" className="btn btn-secondary">Cancelar</Link>
            </div>
          </form>
        </div>
      </main>
    </AuthGuard>
  );
}
