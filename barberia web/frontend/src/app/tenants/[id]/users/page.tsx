'use client';

import Link from 'next/link';
import { FormEvent, useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import { AppNav } from '@/components/AppNav';
import { AuthGuard } from '@/components/AuthGuard';
import { EmptyState } from '@/components/EmptyState';
import { InlineAlert } from '@/components/InlineAlert';
import { LoadingBlock } from '@/components/LoadingBlock';
import { PageHeader } from '@/components/PageHeader';
import { useToast } from '@/components/useToast';
import { api, ApiError, TenantUser } from '@/lib/api';

export default function TenantUsersPage() {
  const params = useParams();
  const tenantId = params.id as string;
  const { showSuccess, showError } = useToast();

  const [users, setUsers] = useState<TenantUser[]>([]);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<'owner' | 'staff'>('owner');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  function load() {
    return api.listUsers(tenantId)
      .then(setUsers)
      .catch((err) => {
        const msg = err instanceof ApiError ? err.message : 'Error al cargar usuarios';
        showError(msg);
      });
  }

  useEffect(() => {
    load().finally(() => setLoading(false));
  }, [tenantId]);

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    setError('');
    setSaving(true);
    try {
      await api.createUser(tenantId, { username, password, role });
      setUsername('');
      setPassword('');
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
    try {
      await api.patchUser(tenantId, user.id, { active: !user.active });
      await load();
      showSuccess(user.active ? 'Usuario desactivado' : 'Usuario activado');
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Error al actualizar usuario';
      showError(msg);
    }
  }

  async function resetPassword(user: TenantUser) {
    const newPassword = window.prompt(`Nueva contraseña para ${user.username}:`);
    if (!newPassword) return;
    try {
      await api.patchUser(tenantId, user.id, { password: newPassword });
      showSuccess('Contraseña actualizada');
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Error al cambiar contraseña';
      showError(msg);
    }
  }

  return (
    <AuthGuard>
      <AppNav />
      <main className="container">
        <PageHeader
          title="Usuarios de app"
          subtitle="Credenciales para la app móvil cuando exista sync. La app en pruebas no se modifica."
        />

        <div className="card">
          <h2>Nuevo usuario</h2>
          <form onSubmit={onCreate}>
            <div className="grid-2">
              <div className="field">
                <label htmlFor="username">Usuario</label>
                <input id="username" value={username} onChange={(e) => setUsername(e.target.value)} required />
              </div>
              <div className="field">
                <label htmlFor="password">Contraseña</label>
                <input id="password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
              </div>
            </div>
            <div className="field">
              <label htmlFor="role">Rol</label>
              <select id="role" value={role} onChange={(e) => setRole(e.target.value as 'owner' | 'staff')}>
                <option value="owner">Owner (admin de barbería)</option>
                <option value="staff">Staff (barbero / recepción)</option>
              </select>
            </div>
            {error && <InlineAlert message={error} />}
            <button type="submit" className="btn btn-primary" disabled={saving}>
              {saving ? 'Creando…' : 'Crear usuario'}
            </button>
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
          <div className="card card-table">
            <table className="table">
              <thead>
                <tr>
                  <th>Usuario</th>
                  <th>Rol</th>
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
                      <span className={u.active ? 'badge badge-active' : 'badge badge-inactive'}>
                        {u.active ? 'Activo' : 'Inactivo'}
                      </span>
                    </td>
                    <td>
                      <button type="button" className="btn btn-secondary" style={{ marginRight: '0.5rem', fontSize: '0.8rem' }} onClick={() => toggleActive(u)}>
                        {u.active ? 'Desactivar' : 'Activar'}
                      </button>
                      <button type="button" className="btn btn-secondary" style={{ fontSize: '0.8rem' }} onClick={() => resetPassword(u)}>
                        Reset pass
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        <Link href={`/tenants/${tenantId}`} className="back-link">← Volver a la barbería</Link>
      </main>
    </AuthGuard>
  );
}
