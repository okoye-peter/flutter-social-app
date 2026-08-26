import { prisma } from '../prisma.js';
import { messaging } from '../firebase.js';
import { HttpError } from '../lib/http-error.js';
import { decodeCursor, buildCursorWhere, toPage, parseLimit, type CursorPage } from '../lib/pagination.js';
import { isRecordNotFoundError } from '../lib/prisma-errors.js';
import type { Notification, NotificationType } from '../../generated/prisma/index.js';

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

export interface CreateNotificationInput {
  userId: string;
  actorId?: string;
  type: NotificationType;
  postId?: string;
  commentId?: string;
  conversationId?: string;
  messageId?: string;
}

function buildNotificationCopy(type: NotificationType, actorName: string): { title: string; body: string } {
  switch (type) {
    case 'FOLLOW':
      return { title: 'New follower', body: `${actorName} started following you` };
    case 'POST_LIKE':
      return { title: 'New like', body: `${actorName} liked your post` };
    case 'POST_COMMENT':
      return { title: 'New comment', body: `${actorName} commented on your post` };
    case 'COMMENT_LIKE':
      return { title: 'New like', body: `${actorName} liked your comment` };
    case 'COMMENT_REPLY':
      return { title: 'New reply', body: `${actorName} replied to your comment` };
    case 'REPOST':
      return { title: 'New repost', body: `${actorName} reposted your post` };
    case 'TAG':
      return { title: 'You were tagged', body: `${actorName} tagged you in a post` };
    case 'MENTION':
      return { title: 'You were mentioned', body: `${actorName} mentioned you` };
    case 'MESSAGE':
      return { title: 'New message', body: `${actorName} sent you a message` };
    case 'CALL':
      return { title: 'Incoming call', body: `${actorName} is calling you` };
  }
}

// Writes the in-app Notification row and best-effort pushes it over FCM.
// Push failure (or no registered devices) must never abort the action that
// triggered it, so sendNotification's errors are swallowed here.
export async function createNotification(input: CreateNotificationInput): Promise<void> {
  const { userId, actorId, type, postId, commentId, conversationId, messageId } = input;
  if (actorId && actorId === userId) return; // suppress self-notifications

  await prisma.notification.create({ data: { userId, actorId, type, postId, commentId, conversationId, messageId } });

  const actor = actorId ? await prisma.user.findUnique({ where: { id: actorId }, select: { name: true } }) : null;
  const { title, body } = buildNotificationCopy(type, actor?.name ?? 'Someone');

  try {
    await sendNotification(userId, title, body, {
      type,
      ...(postId ? { postId } : {}),
      ...(commentId ? { commentId } : {}),
      ...(conversationId ? { conversationId } : {}),
      ...(messageId ? { messageId } : {}),
    });
  } catch {
    // no registered devices, or FCM failure — fine, the in-app row already exists.
  }
}

export async function listNotifications(
  userId: string,
  query: { cursor?: string; limit?: string },
): Promise<CursorPage<Notification> & { unreadCount: number }> {
  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const [rows, unreadCount] = await Promise.all([
    prisma.notification.findMany({
      where: { userId, ...buildCursorWhere(cursor) },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    }),
    prisma.notification.count({ where: { userId, isRead: false } }),
  ]);

  const page = toPage(rows, limit);
  return { ...page, unreadCount };
}

export async function markNotificationRead(notificationId: string, userId: string): Promise<Notification> {
  try {
    return await prisma.notification.update({
      where: { id: notificationId, userId },
      data: { isRead: true, readAt: new Date() },
    });
  } catch (e) {
    if (isRecordNotFoundError(e)) throw new HttpError(404, 'Notification not found');
    throw e;
  }
}

export async function markAllNotificationsRead(userId: string): Promise<{ count: number }> {
  const result = await prisma.notification.updateMany({
    where: { userId, isRead: false },
    data: { isRead: true, readAt: new Date() },
  });
  return { count: result.count };
}
