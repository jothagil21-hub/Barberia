'use client';

import Link from 'next/link';
import { FormEvent, useEffect, useMemo, useState } from 'react';
import { useParams } from 'next/navigation';
import { AppNav } from '@/components/AppNav';
import { AuthGuard } from '@/components/AuthGuard';
import { FileUpload } from '@/components/FileUpload';
import { InlineSpinner } from '@/components/InlineSpinner';
import { LoadingBlock } from '@/components/LoadingBlock';
import { LoadingButton } from '@/components/LoadingButton';
import { PageHeader } from '@/components/PageHeader';
import { SelectField } from '@/components/SelectField';
import { TimePicker } from '@/components/TimePicker';
import { Toggle } from '@/components/Toggle';
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
  const [savingBasic, setSavingBasic] = useState(false);
  const [savingSettings, setSavingSettings] = useState(false);
  const [uploadingLogo, setUploadingLogo] = useState(false);

  const intervalOptions = useMemo(
    () => INTERVALS.map((n) => ({ value: String(n), label: `${n} min` })),
    [],
  );

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
    setSavingBasic(true);
    try {
      const updated = await api.patchTenant(id, { name, active });
      setTenant(updated);
      showSuccess('Datos básicos guardados');
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Error al guardar';
      showError(`No se pudo guardar: ${msg}`);
    } finally {
      setSavingBasic(false);
    }
  }

  async function saveSettings(e: FormEvent) {
    e.preventDefault();
    setSavingSettings(true);
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
      setSavingSettings(false);
    }
  }

  async function onLogoChange(file: File | null) {
    if (!file) return;
    setUploadingLogo(true);
    try {
      const settings = await api.uploadLogo(id, file);
      applySettings(settings);
      showSuccess('Logo actualizado');
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Error al subir logo';
      showError(`No se pudo subir el logo: ${msg}`);
    } finally {
      setUploadingLogo(false);
    }
  }

  const formDisabled = savingBasic || savingSettings || uploadingLogo;

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

        <div className={`card${savingBasic ? ' card-busy' : ''}`}>
          {savingBasic && (
            <div className="card-busy-spinner">
              <InlineSpinner label="Guardando…" />
            </div>
          )}
          <h2>Datos básicos</h2>
          <form onSubmit={saveBasic}>
            <div className="field">
              <label htmlFor="name">Nombre</label>
              <input id="name" value={name} onChange={(e) => setName(e.target.value)} required disabled={formDisabled} />
            </div>
            <div className="field">
              <Toggle
                id="active"
                checked={active}
                onChange={setActive}
                label="Barbería activa"
                disabled={formDisabled}
              />
            </div>
            <LoadingButton type="submit" loading={savingBasic} loadingText="Guardando…" disabled={formDisabled && !savingBasic}>
              Guardar
            </LoadingButton>
          </form>
        </div>

        <div className={`card${savingSettings || uploadingLogo ? ' card-busy' : ''}`}>
          {(savingSettings || uploadingLogo) && (
            <div className="card-busy-spinner">
              <InlineSpinner label={uploadingLogo ? 'Subiendo logo…' : 'Guardando…'} />
            </div>
          )}
          <h2>Configuración (branding y agenda)</h2>
          <p className="muted">Equivalente a Configuración en la app móvil — sin sync aún.</p>
          <form onSubmit={saveSettings}>
            <div className="field">
              <label htmlFor="displayName">Nombre visible en app</label>
              <input id="displayName" value={displayName} onChange={(e) => setDisplayName(e.target.value)} required disabled={formDisabled} />
            </div>
            <div className="field">
              <FileUpload
                previewUrl={logoPreview}
                onChange={onLogoChange}
                disabled={formDisabled}
                uploading={uploadingLogo}
              />
            </div>
            <div className="grid-2">
              <TimePicker
                id="start"
                label="Hora inicio"
                value={scheduleStart}
                onChange={setScheduleStart}
              />
              <TimePicker
                id="end"
                label="Hora cierre"
                value={scheduleEnd}
                onChange={setScheduleEnd}
              />
            </div>
            <SelectField
              id="interval"
              label="Intervalo de cita (min)"
              value={String(scheduleInterval)}
              onChange={(value) => setScheduleInterval(Number(value))}
              options={intervalOptions}
              disabled={formDisabled}
            />
            <LoadingButton type="submit" loading={savingSettings} loadingText="Guardando…" disabled={formDisabled && !savingSettings}>
              Guardar configuración
            </LoadingButton>
          </form>
        </div>

        <Link href="/dashboard" className="back-link">← Volver al listado</Link>
      </main>
    </AuthGuard>
  );
}
