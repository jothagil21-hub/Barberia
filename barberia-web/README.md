# BarberiaApp — Panel web (Fase 5)

Panel super-admin para gestionar barberías desde el navegador. La app móvil (`barberia/`) puede **vincularse** vía sync offline-first.

## API app móvil (`/api/app/*`)

| Método | Ruta | Auth |
|--------|------|------|
| POST | `/api/app/auth/login` | Público — `TenantUser` |
| GET | `/api/app/auth/me` | JWT `tenant_user` |
| GET | `/api/app/sync?since=` | JWT — pull delta |
| POST | `/api/app/sync` | JWT — push cambios + pull |

Tras `db:push`, crear barbería y usuario **owner** en el panel; en la app: **Vincular barbería** con URL del servidor (emulador Android: `http://10.0.2.2:3001`).

## Estructura

```
barberia web/
├── backend/    # API Node.js + Fastify + Prisma + PostgreSQL
└── frontend/   # Panel Next.js
```

## Requisitos

- Node.js 20+ (`nvm use 22`)
- PostgreSQL en Windows (ver [backend/README.md](backend/README.md))

## Arranque rápido

### 1. Backend

```powershell
cd "C:\Temporal\Proyectos\Personales\Barberia\barberia web\backend"
$env:Path = "C:\nvm4w\nodejs;" + $env:Path
nvm use 22
copy .env.example .env
# Editar .env (DATABASE_URL, JWT_SECRET, PLATFORM_ADMIN_PASSWORD)
npm install
npm run db:push
npm run db:seed
npm run dev
```

API: http://localhost:3001/health

### 2. Frontend

```powershell
cd "C:\Temporal\Proyectos\Personales\Barberia\barberia web\frontend"
$env:Path = "C:\nvm4w\nodejs;" + $env:Path
nvm use 22
copy .env.example .env.local
npm install
npm run dev
```

Panel: http://localhost:3000 — login con usuario `admin` y la contraseña de `PLATFORM_ADMIN_PASSWORD`.

## Flujo del panel

1. Login super-admin
2. Dashboard → listado de barberías
3. Nueva barbería / editar / activar-desactivar
4. Configuración: nombre visible, logo, horario (como en app móvil)
5. Usuarios de app por barbería (para sync futuro)

## App móvil

La app en `barberia/` soporta modo **local** (`admin`/`123`) o **vinculada** al panel (usuarios `TenantUser`). Sync offline-first: citas, barberos, servicios, bloqueos y settings.
