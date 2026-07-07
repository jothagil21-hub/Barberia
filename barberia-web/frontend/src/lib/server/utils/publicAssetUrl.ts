/** URL absoluta para assets públicos (logos en /uploads o Blob). */
export function resolvePublicAssetUrl(path: string | null | undefined): string | null {
  if (!path) return null;
  if (path.startsWith('http')) return path;

  const configured = process.env.NEXT_PUBLIC_APP_URL?.trim().replace(/\/$/, '');
  if (configured) return `${configured}${path.startsWith('/') ? path : `/${path}`}`;

  const production = process.env.VERCEL_PROJECT_PRODUCTION_URL?.trim();
  if (production) {
    const host = production.replace(/^https?:\/\//, '');
    return `https://${host}${path.startsWith('/') ? path : `/${path}`}`;
  }

  const vercel = process.env.VERCEL_URL?.trim();
  if (vercel) {
    return `https://${vercel}${path.startsWith('/') ? path : `/${path}`}`;
  }

  return path;
}
