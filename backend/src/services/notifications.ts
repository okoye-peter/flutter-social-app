import { prisma } from '../prisma.js';
import { messaging } from '../firebase.js';
import { HttpError } from '../lib/http-error.js';

export async function registerToken(userId: string, token: string): Promise<void> {
  await prisma.deviceToken.upsert({
    where: { token },
    update: { userId },
    create: { userId, token },
  });
}

export async function sendNotification(
  userId: string,
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<{ successCount: number; failureCount: number }> {
  const rows = await prisma.deviceToken.findMany({ where: { userId } });
  const tokens = rows.map((row) => row.token);
  if (tokens.length === 0) {
    throw new HttpError(404, 'No registered devices for this user');
  }

  const response = await messaging.sendEachForMulticast({ tokens, notification: { title, body }, data });
  return { successCount: response.successCount, failureCount: response.failureCount };
}
