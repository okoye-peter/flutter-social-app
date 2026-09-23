import { Router } from 'express';
import * as commentController from '../controllers/comment.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { updateCommentSchema } from '../schemas/comment.schema.js';

export const commentsRouter = Router();

/**
 * @openapi
 * /comments/{id}:
 *   get:
 *     summary: Get a single comment
 *     tags: [Comments]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The comment.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { comment: { $ref: '#/components/schemas/Comment' } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { $ref: '#/components/responses/NotFound' }
 *   put:
 *     summary: Edit a comment
 *     description: Only the comment's own author can edit it, and only within 15 minutes of posting.
 *     tags: [Comments]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [content]
 *             properties: { content: { type: string, description: 'Max 2000 characters.' } }
 *     responses:
 *       200:
 *         description: The updated comment.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { comment: { $ref: '#/components/schemas/Comment' } } }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { description: 'Not the author, or the 15-minute edit window has passed.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *       404: { $ref: '#/components/responses/NotFound' }
 *   delete:
 *     summary: Delete a comment
 *     description: Only the comment's own author can delete it. Idempotent.
 *     tags: [Comments]
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
commentsRouter.get('/:id', requireAuth, commentController.getComment);
commentsRouter.put('/:id', requireAuth, validate(updateCommentSchema), commentController.updateComment);
commentsRouter.delete('/:id', requireAuth, commentController.deleteComment);

/**
 * @openapi
 * /comments/{id}/replies:
 *   get:
 *     summary: List replies to a comment
 *     tags: [Comments]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of replies.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items: { type: array, items: { $ref: '#/components/schemas/Comment' } }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
commentsRouter.get('/:id/replies', requireAuth, commentController.listReplies);

/**
 * @openapi
 * /comments/{id}/likes:
 *   post:
 *     summary: Like a comment
 *     description: Idempotent.
 *     tags: [Comments]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The comment's updated like count.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { likesCount: { type: integer } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 *       404: { $ref: '#/components/responses/NotFound' }
 *   delete:
 *     summary: Unlike a comment
 *     description: Idempotent.
 *     tags: [Comments]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The comment's updated like count.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { likesCount: { type: integer } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
commentsRouter.post('/:id/likes', requireAuth, commentController.likeComment);
commentsRouter.delete('/:id/likes', requireAuth, commentController.unlikeComment);
