import { Router } from 'express';
import * as reportController from '../controllers/report.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { createReportSchema } from '../schemas/report.schema.js';

export const reportsRouter = Router();

/**
 * @openapi
 * /reports:
 *   post:
 *     summary: Report a post, comment, or user
 *     description: Provide exactly one of postId, commentId, or reportedUserId.
 *     tags: [Reports]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [reason]
 *             properties:
 *               reason: { type: string, enum: [SPAM, HARASSMENT, HATE_SPEECH, NUDITY, VIOLENCE, MISINFORMATION, OTHER] }
 *               details: { type: string }
 *               postId: { type: string }
 *               commentId: { type: string }
 *               reportedUserId: { type: string }
 *     responses:
 *       201:
 *         description: The created report.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { report: { $ref: '#/components/schemas/Report' } } }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { description: 'The reported post/comment/user does not exist.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 */
reportsRouter.post('/', requireAuth, validate(createReportSchema), reportController.createReport);
