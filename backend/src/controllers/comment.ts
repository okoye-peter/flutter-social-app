import type { Request, Response } from 'express';
import * as commentService from '../services/comment.js';
import * as likeService from '../services/like.js';

export async function getComment(req: Request, res: Response) {
  const comment = await commentService.getComment((req.params.id as string));
  res.json({ comment });
}

export async function updateComment(req: Request, res: Response) {
  const { content } = req.body as { content: string };
  const comment = await commentService.updateComment((req.params.id as string), req.userId!, content);
  res.json({ comment });
}

export async function deleteComment(req: Request, res: Response) {
  await commentService.deleteComment((req.params.id as string), req.userId!);
  res.status(204).end();
}

export async function listReplies(req: Request, res: Response) {
  const { cursor, limit } = req.query as { cursor?: string; limit?: string };
  const page = await commentService.listReplies((req.params.id as string), { cursor, limit });
  res.json(page);
}

export async function likeComment(req: Request, res: Response) {
  const result = await likeService.likeComment((req.params.id as string), req.userId!);
  res.json(result);
}

export async function unlikeComment(req: Request, res: Response) {
  const result = await likeService.unlikeComment((req.params.id as string), req.userId!);
  res.json(result);
}
