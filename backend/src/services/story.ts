import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { isUniqueConstraintError } from '../lib/prisma-errors.js';
import { assertNotBlocked } from './block.js';
import { uploadAttachment } from './cloudinary.js';
import { toSafeUser, type SafeUser } from './auth.js';
import type { Story, MediaType } from '../../generated/prisma/index.js';

export const MAX_CAPTION_LENGTH = 500;
const STORY_LIFETIME_MS = 24 * 60 * 60 * 1000;

export interface CreateStoryInput {
  userId: string;
  mediaFile: { buffer: Buffer; mimetype: string };
  caption?: string;
}

export type StoryWithViewerState = Story & { seenByMe: boolean };

export interface StoryGroup {
  user: SafeUser;
  stories: StoryWithViewerState[];
  hasUnseen: boolean;
}

function deriveMediaType(mimetype: string): MediaType {
  if (mimetype.startsWith('video/')) return 'VIDEO';
  if (mimetype.startsWith('image/')) return 'IMAGE';
  throw new HttpError(400, 'Only image or video uploads are allowed');
}

export async function createStory(input: CreateStoryInput): Promise<Story> {
  const { userId, mediaFile, caption } = input;
  const trimmedCaption = caption?.trim() ?? '';

  const mediaType = deriveMediaType(mediaFile.mimetype);
  const mediaUrl = await uploadAttachment(mediaFile.buffer, 'story-media');

  const createdAt = new Date();
  const expiresAt = new Date(createdAt.getTime() + STORY_LIFETIME_MS);

  return prisma.story.create({
    data: { userId, mediaType, mediaUrl, caption: trimmedCaption, createdAt, expiresAt },
  });
}

// Groups every follower/following's active (non-expired) stories by author,
// viewer's own group first, then others ordered unseen-first — mirrors the
// Instagram convention the mobile UI is built against.
export async function listStoriesFeed(viewerId: string): Promise<StoryGroup[]> {
  const following = await prisma.follow.findMany({ where: { followerId: viewerId }, select: { followingId: true } });
  const authorIds = [viewerId, ...following.map((f) => f.followingId)];

  const rows = await prisma.story.findMany({
    where: { userId: { in: authorIds }, expiresAt: { gt: new Date() } },
    orderBy: [{ createdAt: 'asc' }],
    include: {
      user: true,
      views: { where: { viewerId }, select: { id: true } },
    },
  });

  const groups = new Map<string, StoryGroup>();
  for (const row of rows) {
    const { user, views, ...story } = row;
    let group = groups.get(user.id);
    if (!group) {
      group = { user: toSafeUser(user), stories: [], hasUnseen: false };
      groups.set(user.id, group);
    }
    const seenByMe = views.length > 0;
    group.stories.push({ ...story, seenByMe });
    if (!seenByMe) group.hasUnseen = true;
  }

  const own = groups.get(viewerId);
  groups.delete(viewerId);
  const others = [...groups.values()].sort((a, b) => {
    if (a.hasUnseen !== b.hasUnseen) return a.hasUnseen ? -1 : 1;
    const aLatest = a.stories.at(-1)!.createdAt.getTime();
    const bLatest = b.stories.at(-1)!.createdAt.getTime();
    return bLatest - aLatest;
  });

  return own ? [own, ...others] : others;
}

export async function getStory(storyId: string, viewerId: string): Promise<StoryWithViewerState> {
  const story = await prisma.story.findUnique({
    where: { id: storyId },
    include: { views: { where: { viewerId }, select: { id: true } } },
  });
  if (!story || story.expiresAt <= new Date()) throw new HttpError(404, 'Story not found');
  await assertNotBlocked(story.userId, viewerId);

  const { views, ...rest } = story;
  return { ...rest, seenByMe: views.length > 0 };
}

export async function deleteStory(storyId: string, userId: string): Promise<void> {
  const story = await prisma.story.findUnique({ where: { id: storyId }, select: { userId: true } });
  if (!story) return; // already gone — idempotent no-op
  if (story.userId !== userId) throw new HttpError(403, 'Only the story owner can delete it');

  await prisma.story.delete({ where: { id: storyId } });
}

export async function markStoryViewed(storyId: string, viewerId: string): Promise<void> {
  const story = await prisma.story.findUnique({ where: { id: storyId }, select: { userId: true, expiresAt: true } });
  if (!story || story.expiresAt <= new Date()) throw new HttpError(404, 'Story not found');
  await assertNotBlocked(story.userId, viewerId);

  if (story.userId === viewerId) return; // owners don't "view" their own story

  try {
    await prisma.storyView.create({ data: { storyId, viewerId } });
  } catch (e) {
    if (isUniqueConstraintError(e)) return; // already viewed — idempotent no-op
    throw e;
  }
}

export async function listStoryViewers(
  storyId: string,
  ownerId: string,
): Promise<{ viewer: SafeUser; viewedAt: Date }[]> {
  const story = await prisma.story.findUnique({ where: { id: storyId }, select: { userId: true } });
  if (!story) throw new HttpError(404, 'Story not found');
  if (story.userId !== ownerId) throw new HttpError(403, 'Only the story owner can see its viewers');

  const rows = await prisma.storyView.findMany({
    where: { storyId },
    orderBy: { viewedAt: 'desc' },
    include: { viewer: true },
  });

  return rows.map((row) => ({ viewer: toSafeUser(row.viewer), viewedAt: row.viewedAt }));
}
