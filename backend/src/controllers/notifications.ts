import type { Request, Response } from 'express';
import * as notificationsService from '../services/notifications.js';

export async function registerToken(req: Request, res: Response) {
  const { userId, token } = req.body as { userId: string; token: string };
  await notificationsService.registerToken(userId, token);
  res.status(204).end();
}

export async function send(req: Request, res: Response) {
  const { userId, title, body, data } = req.body as {
    userId: string;
    title: string;
    body: string;
    data?: Record<string, string>;
  };
  const result = await notificationsService.sendNotification(userId, title, body, data);
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
