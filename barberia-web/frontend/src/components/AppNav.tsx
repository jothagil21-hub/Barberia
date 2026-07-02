'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { BrandLogo } from '@/components/BrandLogo';
import { clearSession, getUsername } from '@/lib/auth';

/** Barra superior del panel (marca + cerrar sesión). */
export function AppNav() {
  const router = useRouter();

  function logout() {
    clearSession();
    router.replace('/login');
  }

  const username = getUsername();

  return (
    <header className="nav">
      <Link href="/dashboard" className="nav-brand-link">
        <BrandLogo size="sm" />
        <span>BarberiaApp Panel</span>
      </Link>
      <div className="nav-actions">
        {username && <span className="muted" title="Sesión activa">{username}</span>}
        <button type="button" className="btn btn-secondary" onClick={logout}>Salir</button>
      </div>
    </header>
  );
}
