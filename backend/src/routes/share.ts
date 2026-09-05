import { Router } from 'express';
import * as shareController from '../controllers/share.js';

// Public — no requireAuth. Link-preview crawlers (WhatsApp, Twitter, etc.)
// fetch this without any auth token.
export const shareRouter = Router();

shareRouter.get('/posts/:id', shareController.getPostSharePage);
