import { Router } from 'express';
import * as notificationsController from '../controllers/notifications.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { registerTokenSchema, sendNotificationSchema } from '../schemas/notifications.schema.js';

export const notificationsRouter = Router();

/**
 * @openapi
 * /notifications/register-token:
 *   post:
 *     summary: Register a device's FCM push token for the caller
 *     tags: [Notifications]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema: { type: object, required: [token], properties: { token: { type: string } } }
 *     responses:
 *       204: { description: 'Registered.' }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
notificationsRouter.post(
  '/register-token',
  requireAuth,
  validate(registerTokenSchema),
  notificationsController.registerToken,
);

/**
 * @openapi
 * /notifications/send:
 *   post:
 *     summary: Push a notification to the caller's own registered devices
 *     description: Sends only to the authenticated caller's own devices — not a way to message another user.
 *     tags: [Notifications]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [title, body]
 *             properties:
 *               title: { type: string }
 *               body: { type: string }
 *               data: { type: object, additionalProperties: { type: string } }
 *     responses:
 *       200:
 *         description: Delivery result.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties: { successCount: { type: integer }, failureCount: { type: integer } }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { description: 'No registered devices for this user.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 */
notificationsRouter.post('/send', requireAuth, validate(sendNotificationSchema), notificationsController.send);

/**
 * @openapi
 * /notifications:
 *   get:
 *     summary: List the caller's notifications
 *     tags: [Notifications]
 *     parameters:
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of notifications, plus the caller's total unread count.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items: { type: array, items: { $ref: '#/components/schemas/Notification' } }
 *                 nextCursor: { type: string, nullable: true }
 *                 unreadCount: { type: integer }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
notificationsRouter.get('/', requireAuth, notificationsController.list);

/**
 * @openapi
 * /notifications/read-all:
 *   post:
 *     summary: Mark all of the caller's notifications as read
 *     tags: [Notifications]
 *     responses:
 *       200:
 *         description: Number of notifications marked read.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { count: { type: integer } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
notificationsRouter.post('/read-all', requireAuth, notificationsController.markAllRead);

/**
 * @openapi
 * /notifications/{id}/read:
 *   post:
 *     summary: Mark a single notification as read
 *     tags: [Notifications]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The updated notification.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { notification: { $ref: '#/components/schemas/Notification' } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
notificationsRouter.post('/:id/read', requireAuth, notificationsController.markRead);
