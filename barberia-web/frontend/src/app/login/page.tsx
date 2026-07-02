'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { InlineAlert } from '@/components/InlineAlert';
import { useToast } from '@/components/useToast';
import { api, ApiError } from '@/lib/api';
import { setSession } from '@/lib/auth';

export default function LoginPage() {
  const router = useRouter();
  const { showError } = useToast();
  const [username, setUsername] = useState('admin');
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
    <div className="login-page">
      <div className="card login-card">
        <div className="login-brand">
          <h1>BarberiaApp</h1>
          <p className="muted">Panel super-admin de plataforma</p>
        </div>
        <form onSubmit={onSubmit}>
          <div className="field">
            <label htmlFor="username">Usuario</label>
            <input id="username" value={username} onChange={(e) => setUsername(e.target.value)} required />
          </div>
          <div className="field">
            <label htmlFor="password">Contraseña</label>
            <input id="password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
          </div>
          {error && <InlineAlert message={error} />}
          <button type="submit" className="btn btn-primary" disabled={loading} style={{ width: '100%' }}>
            {loading ? 'Entrando…' : 'Iniciar sesión'}
          </button>
        </form>
      </div>
    </div>
  );
}
