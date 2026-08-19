import { Router } from 'express';
import * as notificationsController from '../controllers/notifications.js';
import { requireAuth } from '../middleware/auth.js';

export const notificationsRouter = Router();

notificationsRouter.post('/register-token', notificationsController.registerToken);
notificationsRouter.post('/send', notificationsController.send);

notificationsRouter.get('/', requireAuth, notificationsController.list);
notificationsRouter.post('/read-all', requireAuth, notificationsController.markAllRead);
notificationsRouter.post('/:id/read', requireAuth, notificationsController.markRead);
