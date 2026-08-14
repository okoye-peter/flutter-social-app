import type { Request, Response } from 'express';
import * as authService from '../services/auth.js';

export async function register(req: Request, res: Response) {
  const result = await authService.registerUser(req.body);
  res.status(201).json(result);
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
  const result = await authService.refreshTokens(req.body?.refreshToken);
  res.json(result);
}

export async function logout(req: Request, res: Response) {
  await authService.logoutUser(req.body?.refreshToken);
  res.json({ message: 'Logged out' });
}

export async function forgotPassword(req: Request, res: Response) {
  await authService.requestPasswordReset(req.body?.email);
  res.json({ message: 'If an account with that email exists, a reset link has been sent.' });
}

export async function resetPassword(req: Request, res: Response) {
  await authService.resetPassword(req.body?.token, req.body?.newPassword);
  res.json({ message: 'Password updated successfully' });
}

export async function updateProfile(req: Request, res: Response) {
  const { name, aboutMe } = req.body as { name?: string; aboutMe?: string };
  const user = await authService.updateProfile(req.userId!, {
    name,
    aboutMe,
    imageFile: req.file ? { buffer: req.file.buffer } : undefined,
  });
  res.json({ user });
}
