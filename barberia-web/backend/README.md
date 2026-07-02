# Backend — API del panel BarberiaApp

API REST multi-tenant para el panel super-admin. **No hay sync con la app móvil** en este MVP.

## Requisitos

- Node.js 20+ (`nvm use 22`)
- PostgreSQL instalado en Windows

## 1. Crear base de datos en PostgreSQL

En pgAdmin o psql (como usuario `postgres`):

```sql
CREATE USER barberia WITH PASSWORD 'tu_password';
CREATE DATABASE barberia OWNER barberia;
GRANT ALL PRIVILEGES ON DATABASE barberia TO barberia;
```

## 2. Configurar entorno

```powershell
cd "C:\Temporal\Proyectos\Personales\Barberia\barberia web\backend"
copy .env.example .env
# Editar .env: DATABASE_URL, JWT_SECRET, PLATFORM_ADMIN_PASSWORD
```

## 3. Instalar y preparar DB

```powershell
$env:Path = "C:\nvm4w\nodejs;" + $env:Path
nvm use 22
npm install
npm run db:push
npm run db:seed
```

## 4. Arrancar

```powershell
npm run dev
```

API en `http://localhost:3001`. Probar: `http://localhost:3001/health`

## Estructura del código

```
src/
├── index.ts          # Punto de entrada
├── lib/prisma.ts     # Cliente de base de datos
├── plugins/auth.ts   # JWT para super-admin
├── routes/           # Un archivo por recurso
│   ├── auth.ts
│   ├── tenants.ts
│   └── users.ts
└── utils/schedule.ts # Validación de horarios (como en móvil)
```
