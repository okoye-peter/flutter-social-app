import type { Request, Response } from 'express';
import * as notificationsService from '../services/notifications.js';

export async function registerToken(req: Request, res: Response) {
  const { token } = req.body as { token: string };
  await notificationsService.registerToken(req.userId!, token);
  res.status(204).end();
}

// Sends only to the authenticated caller's own devices — this was
// previously unauthenticated and trusted a client-supplied userId,
// letting anyone push notifications to (or register a device against)
// an arbitrary account.
export async function send(req: Request, res: Response) {
  const { title, body, data } = req.body as {
    title: string;
    body: string;
    data?: Record<string, string>;
  };
  const result = await notificationsService.sendNotification(req.userId!, title, body, data);
  res.json(result);
}

export async function list(req: Request, res: Response) {
  const { cursor, limit } = req.query as { cursor?: string; limit?: string };
  const page = await notificationsService.listNotifications(req.userId!, { cursor, limit });
  res.json(page);
}

export async function markRead(req: Request, res: Response) {
  const notification = await notificationsService.markNotificationRead((req.params.id as string), req.userId!);
  res.json({ notification });
}

export async function markAllRead(req: Request, res: Response) {
  const result = await notificationsService.markAllNotificationsRead(req.userId!);
  res.json(result);
}
