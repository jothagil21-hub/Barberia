'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { BrandLogo } from '@/components/BrandLogo';
import { InlineAlert } from '@/components/InlineAlert';
import { LoadingButton } from '@/components/LoadingButton';
import { useToast } from '@/components/useToast';
import { api, ApiError } from '@/lib/api';
import { setSession } from '@/lib/auth';

const isDev = process.env.NODE_ENV === 'development';

const FEATURES = [
  'Gestiona barberías multi-tenant',
  'Citas sincronizadas en tiempo real',
  'Panel centralizado para owners y staff',
];

function UserIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z"
        stroke="currentColor"
        strokeWidth="1.75"
      />
      <path
        d="M4 20c0-3.3 3.6-6 8-6s8 2.7 8 6"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
      />
    </svg>
  );
}

function LockIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="5" y="11" width="14" height="10" rx="2" stroke="currentColor" strokeWidth="1.75" />
      <path
        d="M8 11V8a4 4 0 1 1 8 0v3"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
      />
    </svg>
  );
}

export default function LoginPage() {
  const router = useRouter();
  const { showError } = useToast();
  const [username, setUsername] = useState(isDev ? 'admin' : '');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await api.login(username, password);
      setSession(res.token, res.username);
      router.replace('/dashboard');
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Error al iniciar sesión';
      setError(msg);
      showError(msg);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-split">
      <aside className="login-brand-panel">
        <div className="login-brand-panel-inner">
          <BrandLogo size="lg" />
          <h1 className="login-brand-title">BarberiaApp</h1>
          <p className="login-brand-tagline">Plataforma de gestión para barberías</p>
          <ul className="login-features">
            {FEATURES.map((feature) => (
              <li key={feature}>{feature}</li>
            ))}
          </ul>
        </div>
      </aside>

      <main className="login-form-panel">
        <div className="login-form-inner">
          <header className="login-form-header">
            <h2>Iniciar sesión</h2>
            <p className="muted">Panel super-admin de plataforma</p>
          </header>

          <form onSubmit={onSubmit}>
            <div className="field">
              <label htmlFor="username">Usuario</label>
              <div className="input-with-icon">
                <span className="input-icon">
                  <UserIcon />
                </span>
                <input
                  id="username"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder={isDev ? 'admin' : 'Tu usuario'}
                  autoComplete="username"
                  required
                />
              </div>
            </div>
            <div className="field">
              <label htmlFor="password">Contraseña</label>
              <div className="input-with-icon">
                <span className="input-icon">
                  <LockIcon />
                </span>
                <input
                  id="password"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete="current-password"
                  required
                />
              </div>
            </div>
            {error && <InlineAlert message={error} />}
            <LoadingButton type="submit" className="btn-block btn-lg" loading={loading} loadingText="Entrando…">
              Iniciar sesión
            </LoadingButton>
          </form>

          <footer className="login-footer">BarberiaApp © 2026</footer>
        </div>
      </main>
    </div>
  );
}
