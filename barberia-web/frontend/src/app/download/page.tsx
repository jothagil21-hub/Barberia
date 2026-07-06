'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { BrandLogo } from '@/components/BrandLogo';
import { ThemeToggle } from '@/components/ThemeToggle';
import {
  ANDROID_APK_FILENAME,
  ANDROID_APK_PATH,
  APP_DISPLAY_VERSION,
  getAndroidApkUrl,
  isLikelyAndroid,
  usesExternalApkUrl,
} from '@/lib/app-download';

type ApkStatus = 'checking' | 'ready' | 'missing';

export default function DownloadPage() {
  const apkUrl = getAndroidApkUrl();
  const externalApk = usesExternalApkUrl();
  const [status, setStatus] = useState<ApkStatus>(externalApk ? 'ready' : 'checking');
  const [autoStarted, setAutoStarted] = useState(false);

  useEffect(() => {
    if (externalApk) return;

    let cancelled = false;

    async function checkLocalApk() {
      try {
        const res = await fetch(ANDROID_APK_PATH, { method: 'HEAD' });
        if (cancelled) return;
        setStatus(res.ok ? 'ready' : 'missing');
      } catch {
        if (!cancelled) setStatus('missing');
      }
    }

    void checkLocalApk();
    return () => {
      cancelled = true;
    };
  }, [externalApk]);

  useEffect(() => {
    if (status !== 'ready' || autoStarted || !isLikelyAndroid()) return;

    const timer = window.setTimeout(() => {
      setAutoStarted(true);
      window.location.assign(apkUrl);
    }, 800);

    return () => window.clearTimeout(timer);
  }, [status, autoStarted, apkUrl]);

  return (
    <div className="download-page">
      <div className="download-page-toolbar">
        <ThemeToggle />
      </div>

      <main className="download-card card">
        <BrandLogo size="lg" />
        <h1 className="download-title">Descargar BarberiaApp</h1>
        <p className="download-subtitle muted">
          App móvil para gestionar citas, barberos y sincronización con tu barbería.
        </p>
        <p className="download-version">Versión {APP_DISPLAY_VERSION} · Android</p>

        {status === 'checking' && (
          <p className="download-status muted">Comprobando instalador…</p>
        )}

        {status === 'missing' && (
          <div className="download-alert">
            <p>
              El instalador no está en este servidor. Para producción configura{' '}
              <code>NEXT_PUBLIC_APK_URL</code> en Vercel (URL de un GitHub Release), o
              coloca <code>{ANDROID_APK_FILENAME}</code> en{' '}
              <code>public/downloads/</code> para pruebas locales.
            </p>
          </div>
        )}

        {status === 'ready' && (
          <>
            <a
              href={apkUrl}
              className="btn btn-block btn-lg download-apk-btn"
              download={externalApk ? undefined : ANDROID_APK_FILENAME}
            >
              Descargar para Android
            </a>
            {autoStarted && (
              <p className="download-hint muted">
                Si la descarga no comenzó, pulsa el botón de arriba.
              </p>
            )}
            {externalApk && (
              <p className="download-hint muted">
                <a href={apkUrl} target="_blank" rel="noopener noreferrer">
                  Enlace directo al instalador
                </a>
              </p>
            )}
          </>
        )}

        <section className="download-steps" aria-label="Instrucciones de instalación">
          <h2>Cómo instalar</h2>
          <ol>
            <li>Abre este enlace desde tu teléfono Android.</li>
            <li>Descarga el archivo APK y ábrelo cuando termine.</li>
            <li>
              Si Android lo pide, permite instalar apps de fuentes desconocidas para tu
              navegador o gestor de archivos.
            </li>
            <li>
              Inicia sesión con el usuario que te creó el administrador en el panel
              (owner o staff).
            </li>
          </ol>
        </section>

        <p className="download-footer-links muted">
          <Link href="/login">Panel web</Link>
          {' · '}
          Solo disponible para Android por ahora.
        </p>
      </main>
    </div>
  );
}
