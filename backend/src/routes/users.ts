import { Router } from 'express';
import * as userController from '../controllers/user.js';
import { requireAuth } from '../middleware/auth.js';
import { uploadProfileImage } from '../middleware/upload.js';

export const usersRouter = Router();

usersRouter.put('/profile', requireAuth, uploadProfileImage.single('image'), userController.updateProfile);
