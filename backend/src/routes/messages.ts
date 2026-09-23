import { Router } from 'express';
import * as messageController from '../controllers/message.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { reactToMessageSchema } from '../schemas/message.schema.js';

export const messagesRouter = Router();

/**
 * @openapi
 * /messages/{id}:
 *   delete:
 *     summary: Delete a message
 *     description: Only the message's own sender can delete it (soft delete). Idempotent.
 *     tags: [Messages]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       204: { description: 'Deleted.' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 */
messagesRouter.delete('/:id', requireAuth, messageController.deleteMessage);

/**
 * @openapi
 * /messages/{id}/reactions:
 *   post:
 *     summary: React to a message with an emoji
 *     description: Setting a new emoji replaces the caller's existing reaction to this message (one reaction per user per message).
 *     tags: [Messages]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema: { type: object, required: [emoji], properties: { emoji: { type: string } } }
 *     responses:
 *       200:
 *         description: The reaction.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 reaction:
 *                   type: object
 *                   properties:
 *                     id: { type: string }
 *                     messageId: { type: string }
 *                     userId: { type: string }
 *                     emoji: { type: string }
 *                     createdAt: { type: string, format: date-time }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 *       404: { $ref: '#/components/responses/NotFound' }
 *   delete:
 *     summary: Remove the caller's reaction to a message
 *     description: Idempotent.
 *     tags: [Messages]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       204: { description: 'Removed.' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
messagesRouter.post('/:id/reactions', requireAuth, validate(reactToMessageSchema), messageController.reactToMessage);
messagesRouter.delete('/:id/reactions', requireAuth, messageController.unreactToMessage);

/**
 * @openapi
 * /messages/{id}/pin:
 *   post:
 *     summary: Pin a message in its conversation
 *     description: In a GROUP conversation, only OWNER/ADMIN members can pin. Idempotent.
 *     tags: [Messages]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The pin.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { pin: { $ref: '#/components/schemas/PinnedMessage' } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { description: 'Only group admins can pin messages.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *       404: { $ref: '#/components/responses/NotFound' }
 *   delete:
 *     summary: Unpin a message
 *     description: In a GROUP conversation, only OWNER/ADMIN members can unpin. Idempotent.
 *     tags: [Messages]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       204: { description: 'Unpinned.' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 */
messagesRouter.post('/:id/pin', requireAuth, messageController.pinMessage);
messagesRouter.delete('/:id/pin', requireAuth, messageController.unpinMessage);
