import { Router } from 'express';
import * as messageController from '../controllers/message.js';
import { requireAuth } from '../middleware/auth.js';

export const messagesRouter = Router();

messagesRouter.delete('/:id', requireAuth, messageController.deleteMessage);

messagesRouter.post('/:id/reactions', requireAuth, messageController.reactToMessage);
messagesRouter.delete('/:id/reactions', requireAuth, messageController.unreactToMessage);

messagesRouter.post('/:id/pin', requireAuth, messageController.pinMessage);
messagesRouter.delete('/:id/pin', requireAuth, messageController.unpinMessage);
