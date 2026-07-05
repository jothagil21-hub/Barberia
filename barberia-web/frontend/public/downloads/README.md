# Instalador Android (APK)

GitHub **rechaza archivos mayores a 100 MB**. Un APK suele pesar 80–150 MB, así que **no lo subas al repositorio**.

## Opción recomendada: GitHub Release + Vercel

### 1. Generar el APK

```powershell
cd C:\Temporal\Proyectos\Personales\Barberia\barberia
flutter build apk --release
```

Salida: `barberia\build\app\outputs\flutter-apk\app-release.apk`

(Si solo existe `app-debug.apk`, sirve para pruebas internas.)

### 2. Crear un Release en GitHub

1. Repo → **Releases** → **Draft a new release**
2. Tag: `v1.0.0`
3. Adjuntar `app-release.apk` renombrado a `barberia-app.apk`
4. Publicar release

Copia la URL del asset, por ejemplo:

`https://github.com/jothagil21-hub/Barberia/releases/download/v1.0.0/barberia-app.apk`

### 3. Variable en Vercel

**Settings → Environment Variables → Production:**

| Variable | Valor |
|----------|--------|
| `NEXT_PUBLIC_APK_URL` | URL del Release de arriba |
| `NEXT_PUBLIC_APP_VERSION` | `1.0.0` (opcional) |

Redeploy. La página `/download` usará esa URL.

---

## Opción local (sin Git)

Para probar en tu PC con `npm run dev`:

```powershell
Copy-Item "C:\Temporal\Proyectos\Personales\Barberia\barberia\build\app\outputs\flutter-apk\app-debug.apk" `
  "C:\Temporal\Proyectos\Personales\Barberia\barberia-web\frontend\public\downloads\barberia-app.apk" -Force
```

Abre http://localhost:3000/download (el `.apk` está en `.gitignore`).

---

## URLs públicas

- Página: `https://barberia-wheat-three.vercel.app/download`
- APK: la de `NEXT_PUBLIC_APK_URL` o `/downloads/barberia-app.apk` en local
