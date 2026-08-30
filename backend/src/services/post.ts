import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { decodeCursor, buildCursorWhere, toPage, parseLimit, type CursorPage } from '../lib/pagination.js';
import { assertNotBlocked } from './block.js';
import { uploadAttachment } from './cloudinary.js';
import { addTags } from './tag.js';
import type { Post, PostKind, MediaType } from '../../generated/prisma/index.js';

export const MAX_CAPTION_LENGTH = 2200;

export interface CreatePostInput {
  userId: string;
  kind?: string;
  caption?: string;
  mediaFile?: { buffer: Buffer; mimetype: string };
  taggedUserIds?: string[];
  soundId?: string;
}

// Deliberately excludes password/email/phoneNumber/fcmToken — this goes
// out to every viewer of the feed, not just the post's own author.
export type PostAuthor = { id: string; name: string; username: string; image: string };

export type PostWithViewerState = Post & {
  user: PostAuthor;
  likedByMe: boolean;
  bookmarkedByMe: boolean;
  repostedByMe: boolean;
};

export interface RepostInfo {
  id: string;
  comment: string | null;
  createdAt: Date;
  repostedBy: PostAuthor;
}

export interface FeedItem {
  post: PostWithViewerState;
  repost: RepostInfo | null;
}

const VIEWER_STATE_INCLUDE = (viewerId: string) => ({
  user: { select: { id: true, name: true, username: true, image: true } },
  likes: { where: { userId: viewerId }, select: { id: true } },
  bookmarks: { where: { userId: viewerId }, select: { id: true } },
  reposts: { where: { userId: viewerId }, select: { id: true } },
});

type PostWithRawViewerState = Post & {
  user: PostAuthor;
  likes: { id: string }[];
  bookmarks: { id: string }[];
  reposts: { id: string }[];
};

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

// Input-shape validation (kind, caption/media presence, caption length,
// the video+soundId conflict) happens in createPostSchema before this
// runs — this only handles what actually needs the DB or the write path.
export async function createPost(input: CreatePostInput): Promise<Post> {
  const { userId, caption, mediaFile, taggedUserIds, soundId } = input;
  const kind = (input.kind ?? 'POST').toUpperCase();
  const trimmedCaption = caption?.trim() ?? '';

  let mediaType: MediaType = 'TEXT';
  let mediaUrl: string | undefined;
  if (mediaFile) {
    mediaType = deriveMediaType(mediaFile.mimetype);
    mediaUrl = await uploadAttachment(mediaFile.buffer, 'post-media');
  }

  if (soundId) {
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

// A feed page interleaves two different tables (original posts and
// reposts, possibly with a quote comment) into one time-ordered stream.
// Fetching `limit + 1` from *each* source before merging is what makes
// this correct: the true top-K of a merge can never need more than K
// items from either single source, so this is enough to guarantee the
// merged top `limit + 1` (and therefore hasMore/nextCursor) is accurate.
type FeedCandidate = { createdAt: Date; id: string; item: FeedItem };

export async function listFeed(
  viewerId: string,
  query: { kind?: string; cursor?: string; limit?: string },
): Promise<CursorPage<FeedItem>> {
  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);
  const kind = query.kind?.toUpperCase();
  if (kind && kind !== 'POST' && kind !== 'REEL') {
    throw new HttpError(400, "kind must be 'POST' or 'REEL'");
  }

  const following = await prisma.follow.findMany({ where: { followerId: viewerId }, select: { followingId: true } });
  const authorIds = [viewerId, ...following.map((f) => f.followingId)];

  const [postRows, repostRows] = await Promise.all([
    prisma.post.findMany({
      where: {
        userId: { in: authorIds },
        ...(kind ? { kind: kind as PostKind } : {}),
        ...buildCursorWhere(cursor),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      include: VIEWER_STATE_INCLUDE(viewerId),
    }),
    prisma.repost.findMany({
      where: {
        userId: { in: authorIds },
        ...(kind ? { post: { kind: kind as PostKind } } : {}),
        ...buildCursorWhere(cursor),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      include: {
        user: { select: { id: true, name: true, username: true, image: true } },
        post: { include: VIEWER_STATE_INCLUDE(viewerId) },
      },
    }),
  ]);

  const postCandidates: FeedCandidate[] = postRows.map((row) => ({
    createdAt: row.createdAt,
    id: row.id,
    item: { post: withViewerState(row), repost: null },
  }));

  const repostCandidates: FeedCandidate[] = repostRows.map((row) => ({
    createdAt: row.createdAt,
    id: row.id,
    item: {
      post: withViewerState(row.post),
      repost: { id: row.id, comment: row.comment, createdAt: row.createdAt, repostedBy: row.user },
    },
  }));

  const merged = [...postCandidates, ...repostCandidates].sort((a, b) => {
    const byDate = b.createdAt.getTime() - a.createdAt.getTime();
    return byDate !== 0 ? byDate : b.id.localeCompare(a.id);
  });

  const page = toPage(merged, limit);
  return { items: page.items.map((c) => c.item), nextCursor: page.nextCursor };
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
