/** Ruta local del APK si se sirve desde `public/downloads/` (solo dev o deploy con archivo presente). */
export const ANDROID_APK_PATH = '/downloads/barberia-app.apk';

export const ANDROID_APK_FILENAME = 'barberia-app.apk';

/** URL externa configurada en Vercel (GitHub Release, etc.). */
export function getExternalApkUrl(): string | null {
  const external = process.env.NEXT_PUBLIC_APK_URL?.trim();
  return external || null;
}

/**
 * URL del instalador. En Vercel usar GitHub Release u otro hosting (GitHub rechaza APK >100 MB en el repo).
 * Ejemplo: https://github.com/jothagil21-hub/Barberia/releases/download/v1.0.0/barberia-app.apk
 */
export function getAndroidApkUrl(): string {
  return getExternalApkUrl() ?? ANDROID_APK_PATH;
}

/** GitHub y otros hosts bloquean HEAD/fetch cross-origin; confiar en la URL configurada. */
export function usesExternalApkUrl(): boolean {
  return getExternalApkUrl() !== null;
}

/** Versión mostrada en la página de descarga; actualizar al publicar un APK nuevo. */
export const APP_DISPLAY_VERSION =
  process.env.NEXT_PUBLIC_APP_VERSION?.trim() || '1.0.0';

export function isLikelyAndroid(): boolean {
  if (typeof navigator === 'undefined') return false;
  return /android/i.test(navigator.userAgent);
}
