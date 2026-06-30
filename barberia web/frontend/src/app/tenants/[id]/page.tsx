'use client';

import Link from 'next/link';
import { FormEvent, useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import { AppNav } from '@/components/AppNav';
import { AuthGuard } from '@/components/AuthGuard';
import { LoadingBlock } from '@/components/LoadingBlock';
import { PageHeader } from '@/components/PageHeader';
import { useToast } from '@/components/useToast';
import { api, ApiError, logoSrc, Tenant, TenantSettings } from '@/lib/api';

const INTERVALS = [15, 20, 30, 45, 60];

export default function TenantDetailPage() {
  const params = useParams();
  const id = params.id as string;
  const { showSuccess, showError } = useToast();

  const [tenant, setTenant] = useState<Tenant | null>(null);
  const [name, setName] = useState('');
  const [active, setActive] = useState(true);
  const [displayName, setDisplayName] = useState('');
  const [scheduleStart, setScheduleStart] = useState('09:00');
  const [scheduleEnd, setScheduleEnd] = useState('21:00');
  const [scheduleInterval, setScheduleInterval] = useState(30);
  const [logoPreview, setLogoPreview] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api.getTenant(id)
      .then((t) => {
        setTenant(t);
        setName(t.name);
        setActive(t.active);
        applySettings(t.settings);
      })
      .catch((err) => {
        const msg = err instanceof ApiError ? err.message : 'Error al cargar la barbería';
        showError(msg);
      })
      .finally(() => setLoading(false));
  }, [id, showError]);

  function applySettings(s: TenantSettings | null) {
    if (!s) return;
    setDisplayName(s.displayName);
    setScheduleStart(s.scheduleStart);
    setScheduleEnd(s.scheduleEnd);
    setScheduleInterval(s.scheduleInterval);
    setLogoPreview(logoSrc(s.logoUrl));
  }

  async function saveBasic(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    try {
      const updated = await api.patchTenant(id, { name, active });
      setTenant(updated);
      showSuccess('Datos básicos guardados');
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Error al guardar';
      showError(`No se pudo guardar: ${msg}`);
    } finally {
      setSaving(false);
    }
  }

  async function saveSettings(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    try {
      const settings = await api.updateSettings(id, {
        displayName,
        scheduleStart,
        scheduleEnd,
        scheduleInterval,
      });
      applySettings(settings);
      showSuccess('Configuración guardada');
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Error al guardar';
      showError(`No se pudo guardar: ${msg}`);
    } finally {
      setSaving(false);
    }
  }

  async function onLogoChange(file: File | null) {
    if (!file) return;
    setSaving(true);
    try {
      const settings = await api.uploadLogo(id, file);
      applySettings(settings);
      showSuccess('Logo actualizado');
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Error al subir logo';
      showError(`No se pudo subir el logo: ${msg}`);
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return (
      <AuthGuard>
        <AppNav />
        <main className="container">
          <LoadingBlock label="Cargando barbería…" />
        </main>
      </AuthGuard>
    );
  }

  if (!tenant) {
    return (
      <AuthGuard>
        <AppNav />
        <main className="container">
          <p className="error">Barbería no encontrada.</p>
          <Link href="/dashboard" className="back-link">← Volver al listado</Link>
        </main>
      </AuthGuard>
    );
  }

  return (
    <AuthGuard>
      <AppNav />
      <main className="container">
        <PageHeader
          title={tenant.name}
          subtitle="Datos del negocio, branding y horario de agenda."
          actions={
            <>
              <Link href={`/tenants/${id}/appointments`} className="btn btn-secondary">
                Ver citas
              </Link>
              <Link href={`/tenants/${id}/services`} className="btn btn-secondary">
                Ver servicios
              </Link>
              <Link href={`/tenants/${id}/users`} className="btn btn-secondary">
                Usuarios de app
              </Link>
            </>
          }
        />

        <div className="card">
          <h2>Datos básicos</h2>
          <form onSubmit={saveBasic}>
            <div className="field">
              <label htmlFor="name">Nombre</label>
              <input id="name" value={name} onChange={(e) => setName(e.target.value)} required />
            </div>
            <div className="field">
              <label>
                <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} style={{ marginRight: '0.5rem' }} />
                Barbería activa
              </label>
            </div>
            <button type="submit" className="btn btn-primary" disabled={saving}>
              {saving ? 'Guardando…' : 'Guardar'}
            </button>
          </form>
        </div>

        <div className="card">
          <h2>Configuración (branding y agenda)</h2>
          <p className="muted">Equivalente a Configuración en la app móvil — sin sync aún.</p>
          <form onSubmit={saveSettings}>
            <div className="field">
              <label htmlFor="displayName">Nombre visible en app</label>
              <input id="displayName" value={displayName} onChange={(e) => setDisplayName(e.target.value)} required />
            </div>
            <div className="field">
              <label>Logo</label>
              <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
                {logoPreview ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={logoPreview} alt="Logo" className="logo-preview" />
                ) : (
                  <div className="logo-preview muted" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '0.75rem' }}>
                    Sin logo
                  </div>
                )}
                <input type="file" accept="image/*" onChange={(e) => onLogoChange(e.target.files?.[0] ?? null)} />
              </div>
            </div>
            <div className="grid-2">
              <div className="field">
                <label htmlFor="start">Hora inicio</label>
                <input id="start" type="time" value={scheduleStart} onChange={(e) => setScheduleStart(e.target.value)} required />
              </div>
              <div className="field">
                <label htmlFor="end">Hora cierre</label>
                <input id="end" type="time" value={scheduleEnd} onChange={(e) => setScheduleEnd(e.target.value)} required />
              </div>
            </div>
            <div className="field">
              <label htmlFor="interval">Intervalo de cita (min)</label>
              <select id="interval" value={scheduleInterval} onChange={(e) => setScheduleInterval(Number(e.target.value))}>
                {INTERVALS.map((n) => (
                  <option key={n} value={n}>{n} min</option>
                ))}
              </select>
            </div>
            <button type="submit" className="btn btn-primary" disabled={saving}>
              {saving ? 'Guardando…' : 'Guardar configuración'}
            </button>
          </form>
        </div>

        <Link href="/dashboard" className="back-link">← Volver al listado</Link>
      </main>
    </AuthGuard>
  );
}
