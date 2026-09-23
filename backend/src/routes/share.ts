import { Router } from 'express';
import * as shareController from '../controllers/share.js';

// Public — no requireAuth. Link-preview crawlers (WhatsApp, Twitter, etc.)
// fetch this without any auth token.
export const shareRouter = Router();

/**
 * @openapi
 * /share/posts/{id}:
 *   get:
 *     summary: Public link-preview page for a post
 *     description: >
 *       Not part of /api and not JSON — returns an unauthenticated HTML page carrying Open
 *       Graph/Twitter Card meta tags so link-preview crawlers (WhatsApp, Twitter, etc.) can render a
 *       rich preview. Deliberately has no viewer-specific data.
 *     tags: [Posts]
 *     security: []
 *     servers: [{ url: '/' }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200: { description: 'HTML preview page.', content: { text/html: { schema: { type: string } } } }
 *       404: { description: 'Post not found.', content: { text/html: { schema: { type: string } } } }
 */
shareRouter.get('/posts/:id', shareController.getPostSharePage);
