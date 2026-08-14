import type { Request, Response } from 'express';
import * as notificationsService from '../services/notifications.js';
import { HttpError } from '../lib/http-error.js';

export async function registerToken(req: Request, res: Response) {
  const { userId, token } = req.body as { userId?: string; token?: string };
  if (!userId || !token) {
    throw new HttpError(400, 'userId and token are required');
  }
  await notificationsService.registerToken(userId, token);
  res.status(204).end();
}

export async function send(req: Request, res: Response) {
  const { userId, title, body, data } = req.body as {
    userId?: string;
    title?: string;
    body?: string;
    data?: Record<string, string>;
  };
  if (!userId || !title || !body) {
    throw new HttpError(400, 'userId, title and body are required');
  }

  const result = await notificationsService.sendNotification(userId, title, body, data);
  res.json(result);
}
