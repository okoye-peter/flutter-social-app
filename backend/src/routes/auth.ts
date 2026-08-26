import { Router } from 'express';
import * as authController from '../controllers/auth.js';
import { requireAuth } from '../middleware/auth.js';
import { uploadProfileImage } from '../middleware/upload.js';
import { validate } from '../middleware/validate.js';
import {
  forgotPasswordSchema,
  loginSchema,
  refreshSchema,
  registerSchema,
  resetPasswordSchema,
  sendEmailOtpSchema,
  sendPhoneOtpSchema,
  verifyEmailOtpSchema,
  verifyPhoneOtpSchema,
} from '../schemas/auth.schema.js';

export const authRouter = Router();

authRouter.post('/register', uploadProfileImage.single('image'), validate(registerSchema), authController.register);
authRouter.post('/login', validate(loginSchema), authController.login);
authRouter.get('/me', requireAuth, authController.me);
authRouter.post('/refresh', validate(refreshSchema), authController.refresh);
authRouter.post('/logout', authController.logout);
authRouter.post('/forgot-password', validate(forgotPasswordSchema), authController.forgotPassword);
authRouter.post('/reset-password', validate(resetPasswordSchema), authController.resetPassword);

authRouter.post('/otp/email/send', validate(sendEmailOtpSchema), authController.sendEmailOtp);
authRouter.post('/otp/email/verify', validate(verifyEmailOtpSchema), authController.verifyEmailOtp);
authRouter.post('/otp/phone/send', validate(sendPhoneOtpSchema), authController.sendPhoneOtp);
authRouter.post('/otp/phone/verify', validate(verifyPhoneOtpSchema), authController.verifyPhoneOtp);
