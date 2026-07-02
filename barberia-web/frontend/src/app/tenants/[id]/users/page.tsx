'use client';

import Link from 'next/link';
import { FormEvent, useEffect, useMemo, useState } from 'react';
import { useParams } from 'next/navigation';
import { AppNav } from '@/components/AppNav';
import { AuthGuard } from '@/components/AuthGuard';
import { EmptyState } from '@/components/EmptyState';
import { InlineAlert } from '@/components/InlineAlert';
import { InlineSpinner } from '@/components/InlineSpinner';
import { LoadingBlock } from '@/components/LoadingBlock';
import { LoadingButton } from '@/components/LoadingButton';
import { PageHeader } from '@/components/PageHeader';
import { PromptDialog } from '@/components/PromptDialog';
import { SelectField } from '@/components/SelectField';
import { useBusy } from '@/hooks/useBusy';
import { useToast } from '@/components/useToast';
import { api, ApiError, TenantBarber, TenantUser } from '@/lib/api';

export default function TenantUsersPage() {
  const params = useParams();
  const tenantId = params.id as string;
  const { showSuccess, showError } = useToast();
  const { isBusy, run, isAnyBusy } = useBusy();

  const [users, setUsers] = useState<TenantUser[]>([]);
  const [barbers, setBarbers] = useState<TenantBarber[]>([]);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<'owner' | 'staff'>('owner');
  const [barberId, setBarberId] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [resetUser, setResetUser] = useState<TenantUser | null>(null);

  function load() {
    return Promise.all([
      api.listUsers(tenantId).then(setUsers),
      api.listBarbers(tenantId).then((res) => setBarbers(res.barbers)),
    ]).catch((err) => {
      const msg = err instanceof ApiError ? err.message : 'Error al cargar usuarios';
      showError(msg);
    });
  }

  useEffect(() => {
    load().finally(() => setLoading(false));
  }, [tenantId]);

  const activeBarbers = barbers.filter((b) => b.active);

  const roleOptions = useMemo(
    () => [
      { value: 'owner', label: 'Owner (admin de barbería)' },
      { value: 'staff', label: 'Staff (solo citas de un barbero)' },
    ],
    [],
  );

  const barberOptions = useMemo(
    () => [
      { value: '', label: 'Seleccionar barbero…' },
      ...activeBarbers.map((b) => ({ value: b.id, label: b.name })),
    ],
    [activeBarbers],
  );

  const tableBarberOptions = useMemo(
    () => [
      { value: '', label: 'Sin asignar' },
      ...activeBarbers.map((b) => ({ value: b.id, label: b.name })),
    ],
    [activeBarbers],
  );

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    setError('');
    if (role === 'staff' && !barberId) {
      setError('Selecciona el barbero que gestionará este usuario staff.');
      return;
    }
    setSaving(true);
    try {
      await api.createUser(tenantId, {
        username,
        password,
        role,
        barberId: role === 'staff' ? barberId : null,
      });
      setUsername('');
      setPassword('');
      setBarberId('');
      await load();
      showSuccess('Usuario creado');
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Error al crear usuario';
      setError(msg);
      showError(`No se pudo crear: ${msg}`);
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive(user: TenantUser) {
    await run(`${user.id}:toggle`, async () => {
      try {
        await api.patchUser(tenantId, user.id, { active: !user.active });
        await load();
        showSuccess(user.active ? 'Usuario desactivado' : 'Usuario activado');
      } catch (err) {
        const msg = err instanceof ApiError ? err.message : 'Error al actualizar usuario';
        showError(msg);
      }
    });
  }

  async function confirmResetPassword(newPassword: string) {
    if (!resetUser) return;
    try {
      await api.patchUser(tenantId, resetUser.id, { password: newPassword });
      showSuccess('Contraseña actualizada');
      setResetUser(null);
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Error al cambiar contraseña';
      showError(msg);
    }
  }

  async function assignStaffBarber(user: TenantUser, nextBarberId: string) {
    if (nextBarberId === (user.barberId ?? '')) return;
    await run(`${user.id}:barber`, async () => {
      try {
        await api.patchUser(tenantId, user.id, { barberId: nextBarberId || null });
        await load();
        showSuccess('Barbero asignado actualizado');
      } catch (err) {
        const msg = err instanceof ApiError ? err.message : 'Error al asignar barbero';
        showError(msg);
      }
    });
  }

  return (
    <AuthGuard>
      <AppNav />
      <main className="container">
        <PageHeader
          title="Usuarios de app"
          subtitle="Owner: acceso completo. Staff: solo citas del barbero asignado."
        />

        <div className={`card${saving ? ' card-busy' : ''}`}>
          {saving && (
            <div className="card-busy-spinner">
              <InlineSpinner label="Creando usuario…" />
            </div>
          )}
          <h2>Nuevo usuario</h2>
          <form onSubmit={onCreate}>
            <div className="grid-2">
              <div className="field">
                <label htmlFor="username">Usuario</label>
                <input id="username" value={username} onChange={(e) => setUsername(e.target.value)} required disabled={saving} />
              </div>
              <div className="field">
                <label htmlFor="password">Contraseña</label>
                <input id="password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} required disabled={saving} />
              </div>
            </div>
            <SelectField
              id="role"
              label="Rol"
              value={role}
              onChange={(value) => setRole(value as 'owner' | 'staff')}
              options={roleOptions}
              disabled={saving}
            />
            {role === 'staff' && (
              <>
                <SelectField
                  id="barberId"
                  label="Barbero asignado"
                  value={barberId}
                  onChange={setBarberId}
                  options={barberOptions}
                  required
                  disabled={saving}
                />
                {activeBarbers.length === 0 && (
                  <p className="muted field-hint">
                    No hay barberos activos. Créalos desde la app móvil (owner) y sincroniza.
                  </p>
                )}
              </>
            )}
            {error && <InlineAlert message={error} />}
            <LoadingButton type="submit" loading={saving} loadingText="Creando…">
              Crear usuario
            </LoadingButton>
          </form>
        </div>

        {loading ? (
          <LoadingBlock label="Cargando usuarios…" />
        ) : users.length === 0 ? (
          <EmptyState
            title="Sin usuarios"
            description="Crea el primer usuario para que pueda acceder a la app móvil."
          />
        ) : (
          <div className={`card card-table${isAnyBusy ? ' card-busy' : ''}`}>
            {isAnyBusy && (
              <div className="card-busy-spinner">
                <InlineSpinner label="Actualizando…" />
              </div>
            )}
            <table className="table">
              <thead>
                <tr>
                  <th>Usuario</th>
                  <th>Rol</th>
                  <th>Barbero</th>
                  <th>Estado</th>
                  <th>Acciones</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => (
                  <tr key={u.id}>
                    <td>{u.username}</td>
                    <td>{u.role}</td>
                    <td>
                      {u.role === 'staff' ? (
                        <SelectField
                          compact
                          value={u.barberId ?? ''}
                          onChange={(value) => void assignStaffBarber(u, value)}
                          options={tableBarberOptions}
                          aria-label={`Barbero asignado para ${u.username}`}
                          disabled={isBusy(`${u.id}:barber`) || isAnyBusy}
                        />
                      ) : (
                        '—'
                      )}
                    </td>
                    <td>
                      <span className={u.active ? 'badge badge-active' : 'badge badge-inactive'}>
                        {u.active ? 'Activo' : 'Inactivo'}
                      </span>
                    </td>
                    <td>
                      <LoadingButton
                        variant="secondary"
                        className="btn-compact"
                        loading={isBusy(`${u.id}:toggle`)}
                        loadingText="…"
                        disabled={isAnyBusy && !isBusy(`${u.id}:toggle`)}
                        onClick={() => void toggleActive(u)}
                      >
                        {u.active ? 'Desactivar' : 'Activar'}
                      </LoadingButton>
                      <LoadingButton
                        variant="secondary"
                        className="btn-compact"
                        disabled={isAnyBusy}
                        onClick={() => setResetUser(u)}
                      >
                        Reset pass
                      </LoadingButton>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        <PromptDialog
          open={resetUser !== null}
          title="Restablecer contraseña"
          description={resetUser ? `Nueva contraseña para ${resetUser.username}.` : undefined}
          label="Nueva contraseña"
          inputType="password"
          confirmLabel="Actualizar"
          loadingLabel="Actualizando…"
          onConfirm={confirmResetPassword}
          onClose={() => setResetUser(null)}
        />

        <Link href={`/tenants/${tenantId}`} className="back-link">← Volver a la barbería</Link>
      </main>
    </AuthGuard>
  );
}
