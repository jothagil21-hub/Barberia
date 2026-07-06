import { cert, getApps, initializeApp, type ServiceAccount } from 'firebase-admin/app';
import { getMessaging, type Messaging } from 'firebase-admin/messaging';

function parseServiceAccount(): ServiceAccount | null {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim();
  if (!raw) return null;

  try {
    const parsed = JSON.parse(raw) as ServiceAccount & { private_key?: string };
    if (parsed.private_key?.includes('\\n')) {
      parsed.private_key = parsed.private_key.replace(/\\n/g, '\n');
    }
    return parsed;
  } catch (error) {
    console.error('[FCM] FIREBASE_SERVICE_ACCOUNT_JSON inválido', error);
    return null;
  }
}

export function getFirebaseMessaging(): Messaging | null {
  const serviceAccount = parseServiceAccount();
  if (!serviceAccount) return null;

  if (getApps().length === 0) {
    initializeApp({ credential: cert(serviceAccount) });
  }

  return getMessaging();
}

export function isFcmConfigured(): boolean {
  return Boolean(process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim());
}
