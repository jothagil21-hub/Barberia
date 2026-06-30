# Barbería — App de citas

App móvil Flutter para gestionar citas de barbería con SQLite local.

## Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x
- Android Studio / Xcode (para emuladores o dispositivos)

Si Flutter no está en el PATH, en este entorno se clonó en:

`C:\Temporal\Proyectos\Personales\flutter_sdk`

```powershell
$env:Path = "C:\Temporal\Proyectos\Personales\flutter_sdk\bin;" + $env:Path
```

## Ejecutar

```powershell
cd barberia
flutter pub get
flutter run
```

## Funcionalidades (MVP)

- Ver citas activas filtradas por día
- Crear cita: día → horario libre (9:00–21:00, cada 30 min) → cliente + servicios
- Cancelar cita (cambio de estado, no eliminación)
- Listado de citas canceladas con filtro opcional por día
- Base de datos local creada en el primer ingreso

## Estructura

```
lib/
├── core/          # Constantes, utilidades, tema
├── data/          # SQLite, modelos, repositorios
├── providers/     # Estado con Riverpod
├── screens/       # Pantallas
└── widgets/       # Componentes reutilizables
```

## Tests

```powershell
flutter test
```

## Documentación

Ver [PLANIFICACION.md](../PLANIFICACION.md) en la raíz del proyecto.
