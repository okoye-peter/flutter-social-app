import { Router } from 'express';
import * as soundController from '../controllers/sound.js';
import { requireAuth } from '../middleware/auth.js';

export const soundsRouter = Router();

/**
 * @openapi
 * /sounds:
 *   get:
 *     summary: List/search sounds, for attaching to a new post
 *     tags: [Sounds]
 *     parameters:
 *       - in: query
 *         name: q
 *         schema: { type: string }
 *         description: Optional title filter.
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of sounds.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items: { type: array, items: { $ref: '#/components/schemas/Sound' } }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
soundsRouter.get('/', requireAuth, soundController.listSounds);

/**
 * @openapi
 * /sounds/{id}:
 *   get:
 *     summary: Get a single sound
 *     tags: [Sounds]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The sound.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { sound: { $ref: '#/components/schemas/Sound' } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
soundsRouter.get('/:id', requireAuth, soundController.getSound);
