# Planeación App Barbería — Flutter + SQLite

Documento de referencia para la implementación de la app móvil de gestión de citas.

---

## Cambios — App vinculada a Vercel (2026)

La app móvil se conecta al panel/API desplegado en Vercel. El usuario final **no ve ni edita la URL** del servidor.

| Tema | Detalle |
|------|---------|
| **URL de producción** | `https://barberia-wheat-three.vercel.app` (constante en `barberia/lib/core/api/api_config.dart`) |
| **URL preview (NO usar)** | URLs con hash (ej. `barberia-7rlqwkam4-...`) — protegidas por login de Vercel |
| **Login app** | Usuario **TenantUser** creado en Panel → Barbería → Usuarios de app (owner/staff) |
| **Login panel web** | Super-admin `admin` + `PLATFORM_ADMIN_PASSWORD` — **no usar en la app móvil** |
| **URL oculta** | Sin campo URL ni botón «Probar conexión» en la pantalla de login |
| **Modo local** | Eliminado de la UI (`admin`/`123` ya no es accesible desde login) |
| **Health check** | `/api/health` (Next.js en Vercel) |
| **Sesión** | Tras login online se guardan token, URL y credenciales en el dispositivo; re-login offline con el mismo usuario del panel |
| **Desarrollo local** | `flutter run --dart-define=API_BASE_URL=http://TU_IP:3000` (solo para desarrolladores) |

### Preview vs producción en Vercel

| Tipo | Ejemplo | ¿Público? |
|------|---------|-----------|
| **Producción** | `barberia-wheat-three.vercel.app` | Sí |
| **Preview** | URLs con hash en el subdominio | No — suele pedir «Log in to Vercel» |

Si el navegador o la app muestran login de **Vercel** (no el de BarberiaApp), la URL es incorrecta o el deploy está protegido.

### Cómo verificar que el servidor es público

1. Abre una ventana de incógnito (sin sesión Vercel).
2. Visita `https://barberia-wheat-three.vercel.app/api/health`.
3. Debe responder `{"status":"ok"}` sin pantalla de Vercel.

### Si solo funciona tras login en Vercel (administrador)

En Vercel → proyecto → **Settings → Deployment Protection**:

1. Asegúrate de que el deploy de la rama `main` esté marcado como **Production**.
2. Usa el dominio de **Domains** sin hash (`barberia-wheat-three.vercel.app`).
3. Desactiva protección en **Preview Deployments** si usabas URLs con hash.
4. Redeploy y vuelve a probar `/api/health` en incógnito.

### Error app: `type 'Null' is not a subtype of...`

Ocurre cuando la app recibe HTML de Vercel en lugar de JSON (preview protegida). Solución: usar dominio de producción + verificación anterior. El cliente HTTP ahora detecta HTML y muestra un mensaje claro.

### Archivos relevantes

- `barberia/lib/core/api/api_config.dart` — URL fija, `effectiveBaseUrl`, `healthCheckPath`
- `barberia/lib/core/api/api_client.dart` — detecta HTML / JSON inválido
- `barberia/lib/core/api/api_models.dart` — validación defensiva en login y sync
- `barberia/lib/screens/login_screen.dart` — solo usuario + contraseña
- `barberia/lib/providers/providers.dart` — sesión solo vinculada al panel
- `barberia/lib/core/sync/sync_service.dart` — siempre usa `ApiConfig.effectiveBaseUrl`
- `barberia/lib/core/sync/sync_session_store.dart` — recuerda solo el último username

---

## Contexto y objetivo

App móvil para gestionar citas en una barbería con **varios barberos**. Permite ver citas por barbero y día, agregar nuevas citas respetando slots de **30 minutos** entre **9:00 y 21:00**, **reagendar** citas activas (fecha, hora, barbero y servicios), y consultar un historial de citas canceladas. La base de datos es **local (SQLite)** y se inicializa en el **primer ingreso**.

**Acceso:** login con usuario de la barbería (TenantUser del panel web). La app se sincroniza con el servidor en Vercel. Los barberos son perfiles de agenda en la app; login individual por barbero queda planificado en Fase 4.

**Marca:** nombre de barbería, logo y nombre visible in-app configurables desde **Configuración** (Fase 3.5). El label bajo el icono Android puede permanecer fijo.

**Plataformas:** Android e iOS (un solo código con Flutter). Desarrollo y pruebas priorizados en Android.

---

## Stack tecnológico

| Capa | Tecnología |
|------|------------|
| Framework | Flutter 3.x + Dart |
| Base de datos | `sqflite` + `path` |
| Estado | `flutter_riverpod` |
| Fechas | `intl` |
| Navegación | `go_router` (rutas protegidas por sesión) |
| Calendario | `showDatePicker` + `DateSelector` (`table_calendar` en deps, no usado aún) |
| Notificaciones | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Export PDF | `pdf`, `path_provider`, `share_plus` |
| Auth | JWT del panel (`tenant_user`) + `shared_preferences` (sesión vinculada y barbero seleccionado) |
| Imágenes | `image_picker` (logo desde galería) |

**Patrón:** Repository + Riverpod. Sync con backend (`barberia web/`) — offline-first, schema SQLite v6.

**Versión de esquema SQLite:** `6`

---

## Modelo de datos

### Tabla `services`

| Campo | Tipo | Notas |
|-------|------|-------|
| `id` | INTEGER PK | Autoincrement |
| `name` | TEXT NOT NULL | Ej: "Corte sencillo" |
| `price` | REAL DEFAULT 0 | Precio editable en catálogo |
| `is_active` | INTEGER DEFAULT 1 | |

**Seed:** Corte sencillo, Corte + barba, Cejas, Barba, Degradado / diseño.

### Tabla `barbers`

| Campo | Tipo | Notas |
|-------|------|-------|
| `id` | INTEGER PK | Autoincrement |
| `name` | TEXT NOT NULL | Editable desde la app |
| `is_active` | INTEGER DEFAULT 1 | |

**Seed:** Barbero 1, Barbero 2.

### Tabla `users`

| Campo | Tipo | Notas |
|-------|------|-------|
| `id` | INTEGER PK | Autoincrement |
| `username` | TEXT UNIQUE | Seed: `admin` |
| `password_hash` | TEXT NOT NULL | bcrypt (nunca en claro) |
| `role` | TEXT NOT NULL | Seed: `admin` |
| `created_at` | TEXT NOT NULL | ISO 8601 |
| `password_change_count` | INTEGER DEFAULT 0 | Tras cada cambio exitoso se incrementa |

**Credencial SQLite legacy:** usuario `admin`, contraseña `123` (seed en primera instalación; **ya no hay UI de login local** — solo referencia histórica en migraciones).

**Cambio de contraseña:** el primer cambio solo requiere contraseña actual + nueva. Desde el segundo cambio se exige **clave maestra** (constante en código, no en DB).

### Tabla `app_settings` (clave-valor)

| key | value por defecto | Uso |
|-----|-------------------|-----|
| `shop_name` | `Barber Shop` | Header, login, PDF |
| `logo_path` | vacío | Ruta local en documents; vacío = icono tijeras |
| `app_display_name` | `Barbería` | `MaterialApp.title` y textos de marca in-app |

### Tabla `appointments`

| Campo | Tipo | Notas |
|-------|------|-------|
| `id` | INTEGER PK | Autoincrement |
| `client_name` | TEXT NOT NULL | |
| `barber_id` | INTEGER NOT NULL FK | Referencia a `barbers` |
| `date` | TEXT NOT NULL | `YYYY-MM-DD` |
| `time` | TEXT NOT NULL | `HH:mm` |
| `status` | TEXT NOT NULL DEFAULT `'scheduled'` | `scheduled` \| `canceled` \| `attended` \| `no_show` |
| `created_at` | TEXT NOT NULL | ISO 8601 |
| `canceled_at` | TEXT NULL | ISO 8601 |

**Índice único parcial (solo citas activas, por barbero):**

```sql
CREATE UNIQUE INDEX idx_active_appointment_slot
ON appointments(barber_id, date, time)
WHERE status = 'scheduled';
```

### Tabla `appointment_services`

| Campo | Tipo |
|-------|------|
| `appointment_id` | INTEGER FK |
| `service_id` | INTEGER FK |
| `unit_price` | REAL | Snapshot del precio al agendar/reagendar |

PK compuesta: `(appointment_id, service_id)`.

### Tabla `barber_schedule_blocks`

| Campo | Tipo | Notas |
|-------|------|-------|
| `id` | INTEGER PK | |
| `barber_id` | INTEGER FK | |
| `date` | TEXT | `YYYY-MM-DD` |
| `time` | TEXT NULL | Slot `HH:mm`; NULL si bloqueo de día completo |
| `is_full_day` | INTEGER | 1 = día entero bloqueado |
| `created_at` | TEXT | ISO 8601 |

Bloqueos impiden crear/reagendar citas en esos horarios. Día completo bloquea los 25 slots del barbero.

### Tabla `schema_meta`

| Campo | Tipo |
|-------|------|
| `key` | TEXT PK |
| `value` | TEXT |

### Migración v1 → v2

1. Crear tablas `users` y `barbers` con seed.
2. `ALTER TABLE appointments ADD COLUMN barber_id DEFAULT 1`.
3. Reemplazar índice único global por índice `(barber_id, date, time)`.
4. Citas existentes quedan asignadas al barbero 1.

### Migración v2 → v3

1. Crear tabla `app_settings` con seed de defaults.
2. `ALTER TABLE users ADD COLUMN password_change_count INTEGER NOT NULL DEFAULT 0`.

### Migración v3 → v4

1. `ALTER TABLE services ADD COLUMN price REAL NOT NULL DEFAULT 0`.
2. `ALTER TABLE appointment_services ADD COLUMN unit_price REAL NOT NULL DEFAULT 0` + backfill desde `services.price`.
3. Crear tabla `barber_schedule_blocks` con índices parciales únicos.

### Migración v4 → v5

1. Seed en `app_settings`: `schedule_start_time`, `schedule_end_time`, `schedule_interval_minutes` (defaults 09:00, 21:00, 30).

---

## Lógica de negocio

### Horarios

- Configurables en **Configuración → Agenda**: hora inicio, hora cierre, duración de cita (15/20/30/45/60 min).
- Por defecto: 09:00–21:00 cada 30 min → **25 slots** por día y barbero.
- Solo citas `scheduled` ocupan un slot.
- Al cancelar: `UPDATE status = 'canceled'` — el slot queda libre para ese barbero.

### Reglas de fechas y horas

1. No permitir **fechas pasadas** al crear cita (`DateSelector`).
2. En el **día actual**, horarios ya vencidos aparecen **visibles pero deshabilitados** (grises); no se pueden seleccionar.
3. Horarios **ocupados** del barbero seleccionado se muestran como **programados** (no seleccionables).
4. Validación en repositorio: no crear/reagendar en fecha+hora pasada (`StateError`).
5. Citas pasadas (fecha/hora vencida) no se pueden reagendar ni cancelar (`canModify`).

### Reglas generales

1. Mínimo un servicio por cita.
2. Las canceladas permanecen en DB y se ven en listado dedicado.
3. Al reagendar, slots libres del barbero (excluyendo la cita actual).
4. Reagendar no modifica el nombre del cliente; sí permite cambiar barbero, fecha, hora y servicios.
5. Home muestra **solo citas del barbero seleccionado** en estado **programada** (no canceladas, asistió ni no asistió).

### Precio en servicios

- Cada servicio tiene precio editable en `/services`.
- Al agendar/reagendar se guarda snapshot `unit_price` por servicio.
- Total visible en tarjeta de cita, detalle y PDF.

### Bloqueo de agenda

- Ruta `/schedule-block` (acceso desde icono en Home junto al calendario).
- Bloquear **día completo** o **slots puntuales** por barbero y fecha.
- Horarios bloqueados visibles en grilla pero no reservables.

### Asistencia

- Citas programadas cuya hora ya pasó pueden marcarse **Asistió** o **No asistió** desde el detalle.
- Al cambiar estado, la cita sale de la agenda del día y libera el slot.

### Autenticación

- Pantalla `/login`; sin sesión no hay acceso a la agenda.
- Sesión persistida en `shared_preferences` (userId, username, role).
- Logout desde menú de perfil en Home.
- Contraseña verificada con bcrypt contra `users.password_hash`.
- Cambio de contraseña en `/profile` con regla de clave maestra a partir del segundo cambio.

### Personalización (Fase 3.5)

- Nombre de barbería editable → header, login, PDF.
- Logo desde galería → login, header, PDF (si existe archivo local).
- Nombre visible in-app → `MaterialApp.title` (no cambia label del launcher Android).
- Settings persistidos en `app_settings`; logo copiado a `documents/shop_logo.jpg`.

### Catálogo de servicios

- Activar/desactivar servicios para promociones temporales.
- Crear servicios nuevos; solo los activos aparecen al agendar/reagendar.
- Citas históricas conservan nombres de servicios aunque estén inactivos.

### Gestión de barberos

- Crear barberos, activar/desactivar, **editar nombre**.
- Solo barberos activos en selector de Home y al agendar.
- Ruta `/barbers`.

### Notificaciones locales (Android)

- Recordatorio **15 minutos antes** de cada cita programada futura.
- Contenido: **barbero**, cliente, hora y servicios.
- Se reprograman al crear, reagendar o cancelar; resync al abrir la app.
- Permisos: `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, lectura de galería para logo.
- Manifest: receivers `ScheduledNotificationReceiver` y `ScheduledNotificationBootReceiver`.
- Solicitud de alarmas exactas en runtime; fallback a modo inexacto si falla.
- Aviso al usuario si la cita queda a menos de 15 min y no se programa recordatorio.

### Exportación PDF

- Rango de fechas configurable (desde/hasta) en `/export`.
- Incluye citas **programadas y canceladas** de **todos los barberos** del rango (no filtra por barbero seleccionado en Home).
- **Agrupación del reporte:**
  - Sección por barbero (solo los que tienen citas en el rango).
  - Subtítulo por fecha (`dd/MM/yyyy`) dentro de cada barbero.
  - Tabla diaria: **Hora | Cliente | Servicios | Total | Estado** (sin columna Fecha repetida).
  - **Subtotal por barbero (asistió):** al cierre de cada sección; suma solo citas con estado `attended`.
  - **Total general (asistió):** al final del reporte; misma regla de suma.
- Las citas programadas, canceladas y no asistió aparecen en el listado con su total por fila, pero **no entran** en subtotales ni total general.
- **Orden:** barberos alfabético por nombre; fechas ascendentes; horas ascendentes dentro de cada día.
- Si no hay citas en el rango: mensaje "No hay citas en el rango seleccionado."
- Encabezado con nombre de barbería y logo si está configurado.
- Compartir vía apps del dispositivo (WhatsApp, Drive, etc.).

**Implementación:** `AppointmentPdfExporter` + `groupAppointmentsForExport` en `core/export/export_appointment_grouper.dart`. Los datos usan `barberName` del JOIN en `getAppointmentsInRange`.

---

## Pantallas y rutas

| Ruta | Pantalla | Descripción |
|------|----------|-------------|
| `/login` | `LoginScreen` | Acceso admin; card con branding dinámico |
| `/` | `HomeScreen` | Agenda del barbero seleccionado, filtro por fecha, FAB nueva cita |
| `/new` | `NewAppointmentScreen` | Barbero → día → hora → cliente + servicios |
| `/appointment/:id` | `AppointmentDetailScreen` | Detalle; reagendar o cancelar si está activa |
| `/appointment/:id/reschedule` | `RescheduleAppointmentScreen` | Reagendar barbero, día, hora y servicios |
| `/barbers` | `BarbersManagementScreen` | CRUD barberos: crear, editar nombre, activar/desactivar |
| `/services` | `ServicesManagementScreen` | Catálogo: activar/desactivar y crear servicios |
| `/schedule-block` | `ScheduleBlockScreen` | Bloquear día o slots de un barbero |
| `/export` | `ExportAppointmentsScreen` | Exportar PDF por rango; agrupado por barbero y fecha |
| `/canceled` | `CanceledAppointmentsScreen` | Historial de canceladas con filtro opcional |
| `/profile` | `ProfileSettingsScreen` | Empresa, logo, nombre in-app, cambio de contraseña |

**Router:** `redirect` a `/login` si no hay sesión.

---

## UI — Home (header)

Layout superior unificado (`HomeTopBar`):

```
[≡ Menú] [Logo]  Barber Shop     [Avatar]
                  admin
```

- **Sin** AppBar duplicado ni título "Agenda".
- Menú (≡) a la **izquierda** del logo.
- Al pulsar menú: overlay con barra horizontal a ancho completo:
  - Barberos, Servicios, Exportar, Canceladas (icono + texto).
- Tap fuera o al elegir opción cierra el overlay.
- Avatar derecho: **Configuración** (`/profile`) y cerrar sesión.

Componentes reutilizables: `BarberSelector`, `DateSelector`, `TimeSlotGrid`, `AppSectionTitle`, `AppointmentCard`, `ShopLogo`.

**Tema:** Material 3 dark, acento dorado `#D4A574`, fondo `#121212`.

---

## Fases de implementación

| Fase | Entregable | Estado |
|------|------------|--------|
| **1** | Proyecto Flutter, DB v1, modelos, repositorios | Hecho |
| **2** | Home, nueva cita, detalle, canceladas, reagendar | Hecho |
| **3** | Catálogo servicios, notificaciones, export PDF (agrupado barbero/fecha), login, multi-barbero | Hecho |
| **3.5** | Perfil, personalización, cambio de contraseña, schema v3 | Hecho |
| **3.6** | Precio servicios, bloqueo agenda, asistió/no asistió, schema v4 | Hecho |
| **3.7** | Notificaciones con barbero y totales PDF por asistió | Hecho |
| **3.8** | Editar cliente y reactivar cita cancelada | Hecho |
| **4** | Login individual por barbero, gestión de usuarios admin | Pospuesta (ver nota abajo) |
| **5** | Panel web multi-empresa (Next.js + API en Vercel) | Hecho |
| **Sync** | App móvil ↔ API offline-first (`TenantUser`, cola sync) | Hecho |

**Nota Fase 4 vs usuarios actuales:** hoy la app usa `TenantUser` del panel (`owner` / `staff`) creados en Panel → Barbería → Usuarios de app. Eso **no** es login 1:1 por perfil de barbero en agenda; Fase 4 sigue pospuesta hasta decidir implementar cuentas por barbero con permisos ampliados desde la app móvil.

---

## Fase 3.5 — Perfil y personalización (completada)

- Pantalla `/profile` accesible desde avatar → Configuración.
- Nombre de barbería editable (Home, login, PDF).
- Logo desde galería del dispositivo (`image_picker`).
- Nombre visible in-app (`MaterialApp.title`).
- Cambio de contraseña: 1.er cambio libre; 2.º y siguientes requieren clave maestra.
- Schema v3: `app_settings`, `users.password_change_count`.

---

## Fase 3.8 — Edición cliente y reactivación (completada)

- Editar nombre del cliente en citas programadas modificables (misma regla que reagendar/cancelar).
- Reactivar citas canceladas si el horario no es pasado, el slot está libre y no está bloqueado.
- Al reactivar: `canceled_at` se limpia y se reprograma recordatorio si aplica.
- Sin cambio de schema adicional tras v5.

---

## Fase 4 — Roadmap futuro (barberos y usuarios) — pospuesta

**Decisión (2026):** permanece pospuesta. El flujo actual con `TenantUser` (`owner` / `staff`) creados en el panel web cubre el caso de uso principal (owner gestiona todo; staff ve su barbero). Fase 4 solo entra en el roadmap si se requiere que cada barbero de agenda tenga credenciales propias gestionadas desde la app móvil.

- **Login individual por barbero:** cada barbero con credenciales propias.
- **Gestión de usuarios desde admin:** crear/editar/desactivar cuentas sin clave maestra manual.
- **Roles ampliados:** permisos diferenciados (admin vs barbero vs recepción).
- Barberos de agenda siguen siendo entidades separadas de cuentas de login, vinculables 1:1.

---

## Fase 5 — Panel web multi-empresa (completada)

Concepto **Empresa**: cada barbería/negocio con su branding, barberos, citas y usuarios.

| Área | Estado |
|------|--------|
| Backend / API | Next.js API routes + Prisma + PostgreSQL (Vercel) |
| Auth super-admin | JWT plataforma (`admin` + `PLATFORM_ADMIN_PASSWORD`) |
| Auth app | JWT `TenantUser` (owner/staff) por barbería |
| Admin web | Tenants, branding, horario, usuarios de app, citas del día (lectura) |
| Sync móvil | Implementado (ver sección Sync abajo) |

Producción: `https://barberia-wheat-three.vercel.app` — ver sección «Cambios — App vinculada a Vercel» al inicio del documento.

---

## Criterios de aceptación

### MVP base (1–9)

1. DB se crea en primer ingreso con servicios y barberos precargados.
2. Citas activas filtrables por día y barbero, ordenadas por hora.
3. Solo horarios libres del barbero al crear cita (9:00–21:00, 30 min).
4. Una sola cita activa por **barbero** + día + hora.
5. Al menos un servicio requerido al guardar.
6. Cancelar cambia estado, no elimina; slot queda libre.
7. Listado separado de citas canceladas.
8. Reagendar: barbero, fecha, hora y servicios; nombre del cliente fijo.
9. Citas pasadas no modificables.

### Fase 2 producto (10–12)

10. Catálogo: activar/desactivar y crear servicios.
11. Notificación local ~15 min antes de citas futuras (Android configurado).
12. Export PDF por rango con estados programada/cancelada, **agrupado por barbero y por fecha** (tabla diaria sin columna Fecha redundante).

### Fase 3 base (13–18)

13. Login `admin` / `123`; contraseña hasheada en DB.
14. Rutas protegidas; sesión persistente; logout en Home.
15. Varios barberos; agenda filtrada por barbero seleccionado.
16. Horarios pasados de hoy visibles pero no seleccionables.
17. Header unificado con menú horizontal (sin "Agenda").
18. Gestión de barberos: crear, editar nombre, activar/desactivar.

### Fase 3.5 — Perfil (19–22)

19. Desde el avatar se accede a Configuración/Perfil.
20. Cambiar nombre de barbería se refleja en Home, login y PDF export.
21. Logo elegido de galería se muestra en login, header y PDF.
22. Nombre in-app editable y usado en `MaterialApp.title`.
23. Primer cambio de contraseña funciona con contraseña actual.
24. Segundo cambio rechazado sin clave maestra; aceptado con clave maestra válida.

### Fase 3.6 — Precio, bloqueo y asistencia (25–28)

25. Servicios con precio editable; total en cita y PDF.
26. Bloqueo de agenda por día completo o slots; no se puede reservar en horarios bloqueados.
27. Citas pasadas programadas: marcar Asistió o No asistió desde detalle.
28. Home lista solo citas en estado programada.

### Fase 3.7 — Notificaciones y totales PDF (29–30)

29. Recordatorio local incluye nombre del barbero en el cuerpo del aviso.
30. PDF export: subtotal por barbero y total general, sumando solo citas con estado asistió.

### Fase 3.8 — Edición cliente y reactivación (31–32)

31. Desde detalle de cita programada modificable se puede editar el nombre del cliente.
32. Citas canceladas con horario futuro se pueden reactivar si el slot sigue libre y no bloqueado.

33. En `/schedule-block`, horarios disponibles y bloqueados se distinguen por estilo visual distinto; leyenda explica cada estado.
34. Al programar o reagendar cita, la rejilla muestra disponible, programado (ya reservado) y bloqueado con colores distintos y leyenda.
35. En Configuración se puede definir hora de inicio, hora de cierre y duración de cada cita; la agenda usa esos valores en toda la app.

---

## Tests

Suite en `barberia/test/`: slots, citas (bloqueo, asistencia, editar cliente, reactivar cancelada), servicios con precio, auth, settings, export agrupado, totales asistió PDF, contenido notificaciones, bloqueos de agenda (colores y leyenda), widget login/home.

Ejecutar: `flutter test` desde `barberia/`.

---

## Pendiente / roadmap

### Completado (antes listado como pendiente)

- ~~Fase 5: panel web super-admin + API~~ → MVP en producción ([`barberia-web/`](barberia-web/frontend/))
- ~~Sync `barberia/` ↔ API~~ → offline-first con `TenantUser`, cola `sync_queue`, despliegue Vercel

### Mejoras recientes (2026)

- Panel web: paleta Barber Gold, login split, modo oscuro, DatePicker en citas, componentes UI unificados
- App móvil: vinculación Vercel, sync settings/comprobantes staff, calendario compacto en Home, fixes UI nueva cita

### Pendiente real

| Ítem | Prioridad | Notas |
|------|-----------|-------|
| **Fase 4** — login individual por barbero + gestión usuarios desde app | Baja (pospuesta) | Hoy: `owner`/`staff` vía panel web; no cuentas 1:1 por barbero de agenda |
| **Pulido visual** — tipografía, icono de app, paleta móvil = web | Media | Paleta móvil alineada a `#C9A962`; tipografía/icono custom opcional |
| **iOS QA** — notificaciones y galería en dispositivo real | Alta si publicas en App Store | Claves Info.plist + init iOS en `NotificationService`; checklist abajo |
| **Dominio propio** — ej. `barberiaapp.com` | Opcional | Comprar dominio + DNS en Vercel; actualizar `api_config.dart` y rebuild APK |

### Checklist iOS (QA manual)

1. Instalar en iPhone/iPad real (`flutter run` o TestFlight).
2. **Galería:** Configuración → Elegir logo → debe pedir permiso y guardar imagen (`NSPhotoLibraryUsageDescription`).
3. **Notificaciones:** crear cita futura → al abrir la app debe solicitarse permiso; verificar aviso ~15 min antes.
4. Si falla alguno, revisar Ajustes → Barberia → Fotos / Notificaciones en el dispositivo.

---

## Fase 5 — Panel web (completada)

Ubicación: [`barberia-web/`](barberia-web/)

```
barberia-web/
├── backend/     # Fastify + Prisma (desarrollo local; producción usa Next.js API en frontend)
└── frontend/    # Next.js panel + API routes (desplegado en Vercel)
```

La app móvil [`barberia/`](barberia/) se vincula al panel vía sync (`TenantUser`, URL fija Vercel).

### Variables backend (`.env`, ver `barberia web/backend/.env.example`)

| Variable | Uso |
|----------|-----|
| `DATABASE_URL` | PostgreSQL local |
| `JWT_SECRET` | Firma JWT super-admin |
| `PLATFORM_ADMIN_PASSWORD` | Seed usuario `admin` — **solo en `.env` local** |
| `PORT` | API (default 3001) |

### Frontend

`NEXT_PUBLIC_API_URL=http://localhost:3001` en `frontend/.env.local`

### Criterios de aceptación Fase 5 (36–40)

36. Proyecto web en `barberia web/backend` + `barberia web/frontend`.
37. Super-admin inicia sesión en el panel con credenciales de seed (env).
38. Crear, editar y desactivar barberías desde el panel.
39. Configurar por barbería: nombre visible, logo, horario inicio/fin/intervalo.
40. Crear y gestionar usuarios de app por barbería (username, rol owner/staff, activo).

**Fuera de alcance MVP:** ~~sync móvil~~ (implementado en fase sync), citas/servicios/barberos en backend para panel (datos vía API app).

---

## Sync móvil ↔ API (offline-first) — completado

- App vinculada con usuario `TenantUser` del panel; URL fija en código (Vercel).
- SQLite local sigue siendo fuente de verdad en el dispositivo; sync al tener red.
- Entidades: settings, barberos, servicios, citas, bloqueos de agenda, comprobantes POS.
- Schema SQLite v6: `server_id`, `sync_status`, cola `sync_queue`.

### Criterios sync (41–45)

41. Login app con `TenantUser` activo; JWT `tenant_user`.
42. Pull inicial trae branding y horario del panel.
43. Crear cita vinculada → push al servidor; segundo dispositivo la recibe en pull.
44. Sin red: la app funciona; cambios quedan `pending` y sync al recuperar conexión.
45. Sin vincular: la app requiere login con TenantUser del panel (modo local `admin`/`123` retirado de la UI).

---

## Estructura relevante (`barberia/lib/`)

```
lib/
├── main.dart, app.dart, router.dart
├── core/
│   └── export/    # appointment_pdf_exporter, export_appointment_grouper
├── data/          # database (schema v5), models, repositories
├── providers/     # auth, settings, barberos, citas, servicios
├── screens/       # login, home, citas, barberos, servicios, export, profile
└── widgets/       # home_top_bar, shop_logo, barber_selector, ...
```

**Credenciales de prueba app (producción):** usuario owner/staff creado en Panel → Barbería → Usuarios de app (no usar super-admin `admin` del panel de plataforma).

**Build Android:** desugaring habilitado en `android/app/build.gradle.kts` (requerido por `flutter_local_notifications`).
