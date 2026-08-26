import { Router } from 'express';
import * as notificationsController from '../controllers/notifications.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { registerTokenSchema, sendNotificationSchema } from '../schemas/notifications.schema.js';

export const notificationsRouter = Router();

notificationsRouter.post('/register-token', validate(registerTokenSchema), notificationsController.registerToken);
notificationsRouter.post('/send', validate(sendNotificationSchema), notificationsController.send);

notificationsRouter.get('/', requireAuth, notificationsController.list);
notificationsRouter.post('/read-all', requireAuth, notificationsController.markAllRead);
notificationsRouter.post('/:id/read', requireAuth, notificationsController.markRead);
