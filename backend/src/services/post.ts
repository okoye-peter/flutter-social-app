import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { decodeCursor, buildCursorWhere, toPage, parseLimit, type CursorPage } from '../lib/pagination.js';
import { assertNotBlocked } from './block.js';
import { uploadAttachment } from './cloudinary.js';
import { addTags } from './tag.js';
import type { Post, PostKind, MediaType } from '../../generated/prisma/index.js';

const MAX_CAPTION_LENGTH = 2200;

export interface CreatePostInput {
  userId: string;
  kind?: string;
  caption?: string;
  mediaFile?: { buffer: Buffer; mimetype: string };
  taggedUserIds?: string[];
  soundId?: string;
}

export type PostWithViewerState = Post & {
  likedByMe: boolean;
  bookmarkedByMe: boolean;
  repostedByMe: boolean;
};

const VIEWER_STATE_INCLUDE = (viewerId: string) => ({
  likes: { where: { userId: viewerId }, select: { id: true } },
  bookmarks: { where: { userId: viewerId }, select: { id: true } },
  reposts: { where: { userId: viewerId }, select: { id: true } },
});

type PostWithRawViewerState = Post & { likes: { id: string }[]; bookmarks: { id: string }[]; reposts: { id: string }[] };

function withViewerState(post: PostWithRawViewerState): PostWithViewerState {
  const { likes, bookmarks, reposts, ...rest } = post;
  return {
    ...rest,
    likedByMe: likes.length > 0,
    bookmarkedByMe: bookmarks.length > 0,
    repostedByMe: reposts.length > 0,
  };
}

function deriveMediaType(mimetype: string): MediaType {
  if (mimetype.startsWith('video/')) return 'VIDEO';
  if (mimetype.startsWith('image/')) return 'IMAGE';
  throw new HttpError(400, 'Only image or video uploads are allowed');
}

export async function createPost(input: CreatePostInput): Promise<Post> {
  const { userId, caption, mediaFile, taggedUserIds, soundId } = input;
  const kind = (input.kind ?? 'POST').toUpperCase();
  if (kind !== 'POST' && kind !== 'REEL') {
    throw new HttpError(400, "kind must be 'POST' or 'REEL'");
  }

  const trimmedCaption = caption?.trim() ?? '';
  if (!trimmedCaption && !mediaFile) {
    throw new HttpError(400, 'A post needs a caption or media');
  }
  if (trimmedCaption.length > MAX_CAPTION_LENGTH) {
    throw new HttpError(400, `Caption must be at most ${MAX_CAPTION_LENGTH} characters`);
  }

  let mediaType: MediaType = 'TEXT';
  let mediaUrl: string | undefined;
  if (mediaFile) {
    mediaType = deriveMediaType(mediaFile.mimetype);
    mediaUrl = await uploadAttachment(mediaFile.buffer, 'post-media');
  }

  if (soundId) {
    if (mediaType === 'VIDEO') {
      throw new HttpError(400, 'Video posts use their own audio and cannot attach a sound');
    }
    const sound = await prisma.sound.findUnique({ where: { id: soundId }, select: { id: true } });
    if (!sound) throw new HttpError(404, 'Sound not found');
  }

  const [post] = await prisma.$transaction([
    prisma.post.create({
      data: { userId, kind: kind as PostKind, mediaType, caption: trimmedCaption, mediaUrl, soundId },
    }),
    prisma.user.update({ where: { id: userId }, data: { postsCount: { increment: 1 } } }),
    ...(soundId ? [prisma.sound.update({ where: { id: soundId }, data: { usageCount: { increment: 1 } } })] : []),
  ]);

  if (taggedUserIds && taggedUserIds.length > 0) {
    await addTags(post.id, userId, taggedUserIds);
  }

  return post;
}

export async function getPost(postId: string, viewerId: string): Promise<PostWithViewerState> {
  const post = await prisma.post.findUnique({
    where: { id: postId },
    include: VIEWER_STATE_INCLUDE(viewerId),
  });
  if (!post) throw new HttpError(404, 'Post not found');
  await assertNotBlocked(post.userId, viewerId);
  return withViewerState(post);
}

export async function deletePost(postId: string, userId: string): Promise<void> {
  const post = await prisma.post.findUnique({ where: { id: postId }, select: { userId: true } });
  if (!post) return; // already gone — idempotent no-op
  if (post.userId !== userId) throw new HttpError(403, 'Only the post owner can delete it');

  await prisma.$transaction([
    prisma.post.delete({ where: { id: postId } }),
    prisma.user.update({ where: { id: userId }, data: { postsCount: { decrement: 1 } } }),
  ]);
}

export async function listFeed(
  viewerId: string,
  query: { kind?: string; cursor?: string; limit?: string },
): Promise<CursorPage<PostWithViewerState>> {
  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);
  const kind = query.kind?.toUpperCase();
  if (kind && kind !== 'POST' && kind !== 'REEL') {
    throw new HttpError(400, "kind must be 'POST' or 'REEL'");
  }

  const following = await prisma.follow.findMany({ where: { followerId: viewerId }, select: { followingId: true } });
  const authorIds = [viewerId, ...following.map((f) => f.followingId)];

  const rows = await prisma.post.findMany({
    where: {
      userId: { in: authorIds },
      ...(kind ? { kind: kind as PostKind } : {}),
      ...buildCursorWhere(cursor),
    },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    include: VIEWER_STATE_INCLUDE(viewerId),
  });

  const page = toPage(rows, limit);
  return { items: page.items.map(withViewerState), nextCursor: page.nextCursor };
}

export async function listUserPosts(
  targetUserId: string,
  viewerId: string,
  kind: 'POST' | 'REEL',
  query: { cursor?: string; limit?: string },
): Promise<CursorPage<PostWithViewerState>> {
  await assertNotBlocked(targetUserId, viewerId);

  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const rows = await prisma.post.findMany({
    where: { userId: targetUserId, kind, ...buildCursorWhere(cursor) },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    include: VIEWER_STATE_INCLUDE(viewerId),
  });

  const page = toPage(rows, limit);
  return { items: page.items.map(withViewerState), nextCursor: page.nextCursor };
}
