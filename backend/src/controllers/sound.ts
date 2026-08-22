import type { Request, Response } from 'express';
import * as soundService from '../services/sound.js';

export async function listSounds(req: Request, res: Response) {
  const { q, cursor, limit } = req.query as { q?: string; cursor?: string; limit?: string };
  const page = await soundService.listSounds({ q, cursor, limit });
  res.json(page);
}

export async function getSound(req: Request, res: Response) {
  const sound = await soundService.getSound(req.params.id as string);
  res.json({ sound });
}
