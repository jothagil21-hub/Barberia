import { prisma } from '@/lib/server/prisma';
import { getFirebaseMessaging, isFcmConfigured } from '@/lib/server/services/notifications/firebaseAdmin';

type PendingNotificationInput = {
  tenantId: string;
  barberId: string;
  appointmentId: string;
  clientName: string;
  clientPhone: string;
  date: string;
  time: string;
  serviceNames: string[];
  barberName: string;
};

const STALE_TOKEN_ERRORS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

function formatPendingBody(input: PendingNotificationInput): string {
  const services = input.serviceNames.join(', ');
  const phoneShort =
    input.clientPhone.length > 6
      ? `${input.clientPhone.slice(0, 3)}…`
      : input.clientPhone;
  return `Nueva solicitud: ${input.clientName} — ${phoneShort} — ${services} — ${input.date} ${input.time}`;
}

async function loadRecipientUserIds(tenantId: string, barberId: string) {
  const users = await prisma.tenantUser.findMany({
    where: {
      tenantId,
      active: true,
      OR: [{ role: 'owner' }, { role: 'staff', barberId }],
    },
    select: { id: true },
  });
  return users.map((u) => u.id);
}

async function removeStaleTokens(tokens: string[]) {
  if (tokens.length === 0) return;
  await prisma.deviceToken.deleteMany({
    where: { fcmToken: { in: tokens } },
  });
}

async function sendFcmToTokens(
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>,
) {
  if (tokens.length === 0) return;

  const messaging = getFirebaseMessaging();
  if (!messaging) {
    if (process.env.NODE_ENV === 'development') {
      console.info('[FCM stub]', title, body, data, `tokens=${tokens.length}`);
    }
    return;
  }

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
    android: { priority: 'high' },
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  });

  const staleTokens: string[] = [];
  response.responses.forEach((result, index) => {
    if (result.success) return;
    const code = result.error?.code;
    console.error('[FCM] send failed', code, result.error?.message, tokens[index]);
    if (code && STALE_TOKEN_ERRORS.has(code)) {
      staleTokens.push(tokens[index]!);
    }
  });

  if (response.failureCount > 0) {
    console.error(
      `[FCM] ${response.failureCount}/${tokens.length} envíos fallaron`,
    );
  }

  await removeStaleTokens(staleTokens);
}

export async function notifyNewPendingRequest(input: PendingNotificationInput) {
  const userIds = await loadRecipientUserIds(input.tenantId, input.barberId);
  if (userIds.length === 0) return;

  const tokens = await prisma.deviceToken.findMany({
    where: { tenantUserId: { in: userIds } },
    select: { fcmToken: true },
  });

  const title = `Solicitud — ${input.barberName}`;
  const body = formatPendingBody(input);
  const data = {
    type: 'pending_request',
    appointmentId: input.appointmentId,
    barberId: input.barberId,
  };

  await sendFcmToTokens(
    tokens.map((t) => t.fcmToken),
    title,
    body,
    data,
  );
}

export async function registerDeviceToken(params: {
  tenantUserId: string;
  fcmToken: string;
  platform: 'android' | 'ios';
}) {
  await prisma.deviceToken.upsert({
    where: {
      tenantUserId_fcmToken: {
        tenantUserId: params.tenantUserId,
        fcmToken: params.fcmToken,
      },
    },
    create: {
      tenantUserId: params.tenantUserId,
      fcmToken: params.fcmToken,
      platform: params.platform,
    },
    update: {
      platform: params.platform,
      updatedAt: new Date(),
    },
  });
}

export { isFcmConfigured };
