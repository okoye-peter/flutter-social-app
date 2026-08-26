import type { Request, Response } from 'express';
import * as messageService from '../services/message.js';
import * as reactionService from '../services/reaction.js';
import * as pinService from '../services/pin.js';

export async function deleteMessage(req: Request, res: Response) {
  await messageService.deleteMessage((req.params.id as string), req.userId!);
  res.status(204).end();
}

export async function reactToMessage(req: Request, res: Response) {
  const { emoji } = req.body as { emoji: string };
  const reaction = await reactionService.reactToMessage((req.params.id as string), req.userId!, emoji);
  res.json({ reaction });
}

export async function unreactToMessage(req: Request, res: Response) {
  await reactionService.unreactToMessage((req.params.id as string), req.userId!);
  res.status(204).end();
}

export async function pinMessage(req: Request, res: Response) {
  const pin = await pinService.pinMessage((req.params.id as string), req.userId!);
  res.json({ pin });
}

export async function unpinMessage(req: Request, res: Response) {
  await pinService.unpinMessage((req.params.id as string), req.userId!);
  res.status(204).end();
}
