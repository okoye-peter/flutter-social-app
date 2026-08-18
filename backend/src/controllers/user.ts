import type { Request, Response } from 'express';
import * as userService from '../services/user.js';

export async function updateProfile(req: Request, res: Response) {
  const { name, aboutMe } = req.body as { name?: string; aboutMe?: string };
  const user = await userService.updateProfile(req.userId!, {
    name,
    aboutMe,
    imageFile: req.file ? { buffer: req.file.buffer } : undefined,
  });
  res.json({ user });
}
