import { Router } from 'express';
import * as soundController from '../controllers/sound.js';
import { requireAuth } from '../middleware/auth.js';

export const soundsRouter = Router();

soundsRouter.get('/', requireAuth, soundController.listSounds);
soundsRouter.get('/:id', requireAuth, soundController.getSound);
