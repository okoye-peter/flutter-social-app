import { Router } from 'express';
import * as authController from '../controllers/auth.js';
import { requireAuth } from '../middleware/auth.js';
import { uploadProfileImage } from '../middleware/upload.js';

export const authRouter = Router();

authRouter.post('/register', authController.register);
authRouter.post('/login', authController.login);
authRouter.get('/me', requireAuth, authController.me);
authRouter.post('/refresh', authController.refresh);
authRouter.post('/logout', authController.logout);
authRouter.post('/forgot-password', authController.forgotPassword);
authRouter.post('/reset-password', authController.resetPassword);
authRouter.put('/profile', requireAuth, uploadProfileImage.single('image'), authController.updateProfile);
