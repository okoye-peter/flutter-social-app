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

/**
 * @openapi
 * /auth/register:
 *   post:
 *     summary: Create an account
 *     description: >
 *       Email and phone must already be OTP-verified (see /auth/otp/*) before this succeeds.
 *       multipart/form-data so an optional profile image can be attached.
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required: [name, username, email, phoneNumber, password]
 *             properties:
 *               name: { type: string }
 *               username: { type: string, description: '3-20 characters: letters, numbers, underscore only' }
 *               email: { type: string }
 *               phoneNumber: { type: string }
 *               password: { type: string, format: password, description: 'At least 6 characters' }
 *               image: { type: string, format: binary }
 *     responses:
 *       201:
 *         description: Account created.
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/TokenPair'
 *                 - type: object
 *                   properties: { user: { $ref: '#/components/schemas/SafeUser' } }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       409: { description: 'Username, email, or phone number already taken.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 */
authRouter.post('/register', uploadProfileImage.single('image'), validate(registerSchema), authController.register);

/**
 * @openapi
 * /auth/login:
 *   post:
 *     summary: Log in with email and password
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email, password]
 *             properties:
 *               email: { type: string }
 *               password: { type: string, format: password }
 *     responses:
 *       200:
 *         description: Logged in.
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/TokenPair'
 *                 - type: object
 *                   properties: { user: { $ref: '#/components/schemas/SafeUser' } }
 *       401: { description: 'Invalid email or password.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 */
authRouter.post('/login', validate(loginSchema), authController.login);

/**
 * @openapi
 * /auth/me:
 *   get:
 *     summary: Get the authenticated user's own profile
 *     tags: [Auth]
 *     responses:
 *       200:
 *         description: The caller's profile.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { user: { $ref: '#/components/schemas/SafeUser' } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
authRouter.get('/me', requireAuth, authController.me);

/**
 * @openapi
 * /auth/refresh:
 *   post:
 *     summary: Exchange a refresh token for a new token pair
 *     description: Rotates the refresh token — the old one is revoked as soon as this succeeds.
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema: { type: object, required: [refreshToken], properties: { refreshToken: { type: string } } }
 *     responses:
 *       200:
 *         description: A new token pair.
 *         content:
 *           application/json:
 *             schema: { $ref: '#/components/schemas/TokenPair' }
 *       401: { description: 'Invalid or expired refresh token.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 */
authRouter.post('/refresh', validate(refreshSchema), authController.refresh);

/**
 * @openapi
 * /auth/logout:
 *   post:
 *     summary: Revoke a refresh token
 *     description: Best-effort and idempotent — a missing or already-revoked token still returns 200.
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       content:
 *         application/json:
 *           schema: { type: object, properties: { refreshToken: { type: string } } }
 *     responses:
 *       200: { description: 'Logged out.' }
 */
authRouter.post('/logout', authController.logout);

/**
 * @openapi
 * /auth/forgot-password:
 *   post:
 *     summary: Request a password-reset code by email
 *     description: Always returns 200 regardless of whether the email is registered, to avoid leaking account existence.
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema: { type: object, required: [email], properties: { email: { type: string } } }
 *     responses:
 *       200: { description: 'If an account exists, a 6-digit reset code was emailed.' }
 *       400: { $ref: '#/components/responses/BadRequest' }
 */
authRouter.post('/forgot-password', validate(forgotPasswordSchema), authController.forgotPassword);

/**
 * @openapi
 * /auth/reset-password:
 *   post:
 *     summary: Reset a password using the code from the forgot-password email
 *     description: The code expires 10 minutes after it's issued and allows up to 5 attempts.
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email, code, newPassword]
 *             properties:
 *               email: { type: string }
 *               code: { type: string, description: '6-digit code emailed by /auth/forgot-password' }
 *               newPassword: { type: string, format: password, description: 'At least 6 characters' }
 *     responses:
 *       200: { description: 'Password updated.' }
 *       400: { description: 'Invalid or expired code.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *       429: { description: 'Too many incorrect attempts for this code.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 */
authRouter.post('/reset-password', validate(resetPasswordSchema), authController.resetPassword);

/**
 * @openapi
 * /auth/otp/email/send:
 *   post:
 *     summary: Send a one-time verification code to an email address
 *     description: Required before that email can be used in /auth/register.
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema: { type: object, required: [email], properties: { email: { type: string } } }
 *     responses:
 *       200: { description: 'Verification code sent.' }
 *       400: { $ref: '#/components/responses/BadRequest' }
 */
authRouter.post('/otp/email/send', validate(sendEmailOtpSchema), authController.sendEmailOtp);

/**
 * @openapi
 * /auth/otp/email/verify:
 *   post:
 *     summary: Verify an email OTP code
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email]
 *             properties: { email: { type: string }, code: { type: string } }
 *     responses:
 *       200: { description: 'Email verified.' }
 *       400: { description: 'Missing/incorrect/expired code.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 */
authRouter.post('/otp/email/verify', validate(verifyEmailOtpSchema), authController.verifyEmailOtp);

/**
 * @openapi
 * /auth/otp/phone/send:
 *   post:
 *     summary: Send a one-time verification code by SMS
 *     description: Required before that phone number can be used in /auth/register.
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema: { type: object, required: [phoneNumber], properties: { phoneNumber: { type: string } } }
 *     responses:
 *       200: { description: 'Verification code sent.' }
 *       400: { $ref: '#/components/responses/BadRequest' }
 */
authRouter.post('/otp/phone/send', validate(sendPhoneOtpSchema), authController.sendPhoneOtp);

/**
 * @openapi
 * /auth/otp/phone/verify:
 *   post:
 *     summary: Verify a phone OTP code
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [phoneNumber]
 *             properties: { phoneNumber: { type: string }, code: { type: string } }
 *     responses:
 *       200: { description: 'Phone number verified.' }
 *       400: { description: 'Missing/incorrect/expired code.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 */
authRouter.post('/otp/phone/verify', validate(verifyPhoneOtpSchema), authController.verifyPhoneOtp);
