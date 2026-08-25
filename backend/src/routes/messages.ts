import { Router } from 'express';
import * as messageController from '../controllers/message.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { reactToMessageSchema } from '../schemas/message.schema.js';

export const messagesRouter = Router();

messagesRouter.delete('/:id', requireAuth, messageController.deleteMessage);

messagesRouter.post('/:id/reactions', requireAuth, validate(reactToMessageSchema), messageController.reactToMessage);
messagesRouter.delete('/:id/reactions', requireAuth, messageController.unreactToMessage);

messagesRouter.post('/:id/pin', requireAuth, messageController.pinMessage);
messagesRouter.delete('/:id/pin', requireAuth, messageController.unpinMessage);
