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

1. Root directory: `barberia-web/frontend` (sin espacios en la ruta)
2. Variables: `DATABASE_URL`, `JWT_SECRET`, `PLATFORM_ADMIN_PASSWORD` (solo seed)
3. **Logos:** Vercel → Storage → Blob → crear store y conectar al proyecto. Vercel inyecta `BLOB_STORE_ID` (y a veces `BLOB_READ_WRITE_TOKEN`). `BLOB_WEBHOOK_PUBLIC_KEY` es opcional y no se usa para subir logos.
4. Tras conectar Postgres: `npm run db:push` y `npm run db:seed` desde tu PC apuntando a la BD de producción
5. Usa el dominio de **producción** (`https://barberia-wheat-three.vercel.app`), no URLs preview con hash
6. Probar en incógnito: `https://barberia-wheat-three.vercel.app/api/health` → `{"status":"ok"}` sin login de Vercel

### Logos (Vercel Blob)

Los logos se guardan en **Vercel Blob** cuando existe `BLOB_READ_WRITE_TOKEN` (producción). La URL pública absoluta se persiste en la base de datos. En desarrollo local sin token, se usa la carpeta `uploads/` del proyecto.

Tras el primer deploy con Blob, **vuelve a subir el logo** de cada barbería (panel o app móvil): los `logoUrl` antiguos (`/uploads/...`) no migran solos y seguirán devolviendo 404.

### Deployment Protection

Si `/api/health` muestra «Log in to Vercel», el deploy está protegido o usas una URL preview. En **Settings → Deployment Protection**, desactiva protección en previews o usa el dominio Production de la pestaña **Domains**. Ver `PLANIFICACION.md` sección «App vinculada a Vercel».

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
