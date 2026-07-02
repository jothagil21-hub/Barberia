/**
 * Sesión del super-admin en el navegador (localStorage).
 * El token JWT se envía en cada petición a la API.
 */
const TOKEN_KEY = 'barberia_platform_token';
const USERNAME_KEY = 'barberia_platform_username';

export function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function getUsername(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(USERNAME_KEY);
}

export function setSession(token: string, username: string) {
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem(USERNAME_KEY, username);
}

export function clearSession() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USERNAME_KEY);
}
