# Panel Next.js — BarberiaApp

Ver [README principal](../README.md) para el flujo completo.

## Desarrollo local

```powershell
copy .env.example .env.local
# Editar DATABASE_URL, JWT_SECRET, PLATFORM_ADMIN_PASSWORD
npm install
npm run db:push
npm run db:seed
npm run dev
```

Abre http://localhost:3000

- **API migrada a Next.js:** panel (`/api/platform/*`), app móvil (`/api/app/*`), `/api/health`, `/api/uploads/*`
- **Same-origin (local y Vercel):** deja `NEXT_PUBLIC_API_URL` vacío — panel y sync usan el mismo servidor
- **Backend Fastify (`:3001`):** ya no es necesario salvo que quieras comparar durante la transición

## Deploy en Vercel

1. Root directory: `barberia web/frontend`
2. Variables: `DATABASE_URL`, `JWT_SECRET`, `PLATFORM_ADMIN_PASSWORD` (solo seed)
3. Tras conectar Postgres: `npm run db:push` y `npm run db:seed` desde tu PC apuntando a la BD de producción
4. Probar: `https://tu-app.vercel.app/api/health`

## Feedback con toasts

El panel usa un sistema de toasts global. En pantallas nuevas (`'use client'`):

```tsx
import { useToast } from '@/components/useToast';

export default function MiPagina() {
  const { showSuccess, showError, showInfo } = useToast();

  async function guardar() {
    try {
      await api.algo();
      showSuccess('Guardado correctamente');
    } catch (err) {
      showError('No se pudo guardar');
    }
  }
}
```

- **Éxito / info:** se ocultan solos tras ~5 s.
- **Error:** permanecen hasta cerrar manualmente.
- Para errores de formulario junto al campo, usa `InlineAlert`.
- Para cabeceras, carga y vacíos: `PageHeader`, `LoadingBlock`, `EmptyState` en `src/components/`.
