import type { Request, Response } from 'express';
import * as authService from '../services/auth.js';
import * as otpService from '../services/otp.js';

export async function register(req: Request, res: Response) {
  const { name, username, email, phoneNumber, password } = req.body as {
    name: string;
    username: string;
    email: string;
    phoneNumber: string;
    password: string;
  };
  const result = await authService.registerUser({
    name,
    username,
    email,
    phoneNumber,
    password,
    imageFile: req.file ? { buffer: req.file.buffer } : undefined,
  });
  res.status(201).json(result);
}

export async function sendEmailOtp(req: Request, res: Response) {
  const { email } = req.body as { email: string };
  await otpService.sendOtp(email.trim().toLowerCase(), 'EMAIL');
  res.json({ message: 'Verification code sent' });
}

export async function verifyEmailOtp(req: Request, res: Response) {
  const { email, code } = req.body as { email: string; code?: string };
  await otpService.verifyOtp(email.trim().toLowerCase(), 'EMAIL', code);
  res.json({ message: 'Email verified' });
}

export async function sendPhoneOtp(req: Request, res: Response) {
  const { phoneNumber } = req.body as { phoneNumber: string };
  await otpService.sendOtp(phoneNumber.trim(), 'PHONE');
  res.json({ message: 'Verification code sent' });
}

export async function verifyPhoneOtp(req: Request, res: Response) {
  const { phoneNumber, code } = req.body as { phoneNumber: string; code?: string };
  await otpService.verifyOtp(phoneNumber.trim(), 'PHONE', code);
  res.json({ message: 'Phone number verified' });
}

export async function login(req: Request, res: Response) {
  const result = await authService.loginUser(req.body);
  res.json(result);
}

export async function me(req: Request, res: Response) {
  const user = await authService.getUserById(req.userId!);
  res.json({ user });
}

export async function refresh(req: Request, res: Response) {
  const result = await authService.refreshTokens(req.body.refreshToken);
  res.json(result);
}

export async function logout(req: Request, res: Response) {
  await authService.logoutUser(req.body?.refreshToken);
  res.json({ message: 'Logged out' });
}

export async function forgotPassword(req: Request, res: Response) {
  await authService.requestPasswordReset(req.body.email);
  res.json({ message: 'If an account with that email exists, a reset link has been sent.' });
}

export async function resetPassword(req: Request, res: Response) {
  await authService.resetPassword(req.body.token, req.body.newPassword);
  res.json({ message: 'Password updated successfully' });
}
