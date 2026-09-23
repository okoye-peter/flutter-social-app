import type { Request, Response } from 'express';
import * as postService from '../services/post.js';
import * as commentService from '../services/comment.js';
import * as likeService from '../services/like.js';
import * as bookmarkService from '../services/bookmark.js';
import * as repostService from '../services/repost.js';
import * as tagService from '../services/tag.js';
import * as soundService from '../services/sound.js';

export async function createPost(req: Request, res: Response) {
  const { kind, caption, taggedUserIds, soundId } = req.body as {
    kind?: string;
    caption?: string;
    taggedUserIds?: string[];
    soundId?: string;
  };
  const post = await postService.createPost({
    userId: req.userId!,
    kind,
    caption,
    mediaFile: req.file ? { buffer: req.file.buffer, mimetype: req.file.mimetype } : undefined,
    taggedUserIds,
    soundId,
  });
  res.status(201).json({ post });
}

export async function getPostSound(req: Request, res: Response) {
  const sound = await soundService.getOrCreateSoundForPost(req.params.id as string);
  res.json({ sound });
}

export async function listFeed(req: Request, res: Response) {
  const { kind, cursor, limit } = req.query as { kind?: string; cursor?: string; limit?: string };
  const page = await postService.listFeed(req.userId!, { kind, cursor, limit });
  res.json(page);
}

export async function getPost(req: Request, res: Response) {
  const post = await postService.getPost((req.params.id as string), req.userId!);
  res.json({ post });
}

export async function deletePost(req: Request, res: Response) {
  await postService.deletePost((req.params.id as string), req.userId!);
  res.status(204).end();
}

export async function listComments(req: Request, res: Response) {
  const { cursor, limit } = req.query as { cursor?: string; limit?: string };
  const page = await commentService.listComments((req.params.id as string), req.userId!, { cursor, limit });
  res.json(page);
}

export async function createComment(req: Request, res: Response) {
  const { content, replyToId } = req.body as { content: string; replyToId?: string };
  const comment = await commentService.createComment((req.params.id as string), req.userId!, content, replyToId);
  res.status(201).json({ comment });
}

export async function likePost(req: Request, res: Response) {
  const result = await likeService.likePost((req.params.id as string), req.userId!);
  res.json(result);
}

export async function unlikePost(req: Request, res: Response) {
  const result = await likeService.unlikePost((req.params.id as string), req.userId!);
  res.json(result);
}

export async function bookmarkPost(req: Request, res: Response) {
  const result = await bookmarkService.bookmarkPost((req.params.id as string), req.userId!);
  res.json(result);
}

export async function unbookmarkPost(req: Request, res: Response) {
  const result = await bookmarkService.unbookmarkPost((req.params.id as string), req.userId!);
  res.json(result);
}

export async function listMyBookmarks(req: Request, res: Response) {
  const { cursor, limit } = req.query as { cursor?: string; limit?: string };
  const page = await bookmarkService.listBookmarks(req.userId!, { cursor, limit });
  res.json(page);
}

export async function repost(req: Request, res: Response) {
  const { comment } = req.body as { comment?: string };
  const result = await repostService.repost((req.params.id as string), req.userId!, comment);
  res.status(201).json(result);
}

export async function unrepost(req: Request, res: Response) {
  const result = await repostService.unrepost((req.params.id as string), req.userId!);
  res.json(result);
}

export async function addTags(req: Request, res: Response) {
  const { userIds } = req.body as { userIds: string[] };
  const tags = await tagService.addTags((req.params.id as string), req.userId!, userIds);
  res.json({ tags });
}

export async function removeTag(req: Request, res: Response) {
  await tagService.removeTag((req.params.id as string), req.userId!, (req.params.userId as string));
  res.status(204).end();
}
