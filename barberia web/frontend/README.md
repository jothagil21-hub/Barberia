# Panel Next.js — BarberiaApp

Ver [README principal](../README.md) para el flujo completo.

```powershell
copy .env.example .env.local
npm install
npm run dev
```

Abre http://localhost:3000 (requiere backend en :3001).

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
