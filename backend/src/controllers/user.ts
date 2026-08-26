import type { Request, Response } from 'express';
import * as userService from '../services/user.js';
import * as followService from '../services/follow.js';
import * as blockService from '../services/block.js';
import * as postService from '../services/post.js';
import * as repostService from '../services/repost.js';
import * as tagService from '../services/tag.js';

export async function updateProfile(req: Request, res: Response) {
  const { name, aboutMe } = req.body as { name?: string; aboutMe?: string };
  const user = await userService.updateProfile(req.userId!, {
    name,
    aboutMe,
    imageFile: req.file ? { buffer: req.file.buffer } : undefined,
  });
  res.json({ user });
}

export async function getProfile(req: Request, res: Response) {
  const profile = await userService.getUserProfile((req.params.id as string), req.userId!);
  res.json(profile);
}

type ListQuery = { cursor?: string; limit?: string };

export async function listUserPosts(req: Request, res: Response) {
  const page = await postService.listUserPosts((req.params.id as string), req.userId!, 'POST', req.query as ListQuery);
  res.json(page);
}

export async function listUserReels(req: Request, res: Response) {
  const page = await postService.listUserPosts((req.params.id as string), req.userId!, 'REEL', req.query as ListQuery);
  res.json(page);
}

export async function listUserReposts(req: Request, res: Response) {
  const page = await repostService.listReposts((req.params.id as string), req.query as ListQuery);
  res.json(page);
}

export async function listUserTagged(req: Request, res: Response) {
  const page = await tagService.listTagged((req.params.id as string), req.query as ListQuery);
  res.json(page);
}

export async function follow(req: Request, res: Response) {
  const result = await followService.followUser(req.userId!, (req.params.id as string));
  res.json(result);
}

export async function unfollow(req: Request, res: Response) {
  const result = await followService.unfollowUser(req.userId!, (req.params.id as string));
  res.json(result);
}

export async function listFollowers(req: Request, res: Response) {
  const page = await followService.listFollowers((req.params.id as string), req.query as ListQuery);
  res.json(page);
}

export async function listFollowing(req: Request, res: Response) {
  const page = await followService.listFollowing((req.params.id as string), req.query as ListQuery);
  res.json(page);
}

export async function block(req: Request, res: Response) {
  await blockService.blockUser(req.userId!, (req.params.id as string));
  res.status(204).end();
}

export async function unblock(req: Request, res: Response) {
  await blockService.unblockUser(req.userId!, (req.params.id as string));
  res.status(204).end();
}

export async function listBlocked(req: Request, res: Response) {
  const page = await blockService.listBlocked(req.userId!, req.query as ListQuery);
  res.json(page);
}
