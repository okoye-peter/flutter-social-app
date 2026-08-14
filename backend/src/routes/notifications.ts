import { Router } from 'express';
import * as notificationsController from '../controllers/notifications.js';

export const notificationsRouter = Router();

notificationsRouter.post('/register-token', notificationsController.registerToken);
notificationsRouter.post('/send', notificationsController.send);
