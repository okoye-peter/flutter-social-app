import type { Request, Response } from 'express';
import * as storyService from '../services/story.js';

export async function createStory(req: Request, res: Response) {
  const { caption } = req.body as { caption?: string };
  const story = await storyService.createStory({
    userId: req.userId!,
    mediaFile: { buffer: req.file!.buffer, mimetype: req.file!.mimetype },
    caption,
  });
  res.status(201).json({ story });
}

export async function listStoriesFeed(req: Request, res: Response) {
  const groups = await storyService.listStoriesFeed(req.userId!);
  res.json({ groups });
}

export async function getStory(req: Request, res: Response) {
  const story = await storyService.getStory((req.params.id as string), req.userId!);
  res.json({ story });
}

export async function deleteStory(req: Request, res: Response) {
  await storyService.deleteStory((req.params.id as string), req.userId!);
  res.status(204).end();
}

export async function markStoryViewed(req: Request, res: Response) {
  await storyService.markStoryViewed((req.params.id as string), req.userId!);
  res.status(204).end();
}

export async function listStoryViewers(req: Request, res: Response) {
  const viewers = await storyService.listStoryViewers((req.params.id as string), req.userId!);
  res.json({ viewers });
}
