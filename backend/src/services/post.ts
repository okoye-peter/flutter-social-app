import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { decodeCursor, buildCursorWhere, toPage, parseLimit, type CursorPage } from '../lib/pagination.js';
import { assertNotBlocked } from './block.js';
import { uploadAttachment } from './cloudinary.js';
import { addTags } from './tag.js';
import { VIEWER_STATE_INCLUDE, withViewerState, type PostAuthor, type PostWithViewerState } from './post-view-state.js';
import type { Post, PostKind, MediaType } from '../../generated/prisma/index.js';

export type { PostAuthor, PostWithViewerState } from './post-view-state.js';

export const MAX_CAPTION_LENGTH = 2200;

export interface CreatePostInput {
  userId: string;
  kind?: string;
  caption?: string;
  mediaFile?: { buffer: Buffer; mimetype: string };
  taggedUserIds?: string[];
  soundId?: string;
}

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

export interface PostPreview {
  caption: string;
  mediaType: MediaType;
  mediaUrl: string | null;
  thumbnailUrl: string | null;
  user: { name: string; username: string };
}

// Unauthenticated preview for the public share/link-unfurl page — no
// viewer-specific state (likedByMe etc.), so no viewerId/block check.
export async function getPostPreview(postId: string): Promise<PostPreview> {
  const post = await prisma.post.findUnique({
    where: { id: postId },
    select: {
      caption: true,
      mediaType: true,
      mediaUrl: true,
      thumbnailUrl: true,
      user: { select: { name: true, username: true } },
    },
  });
  if (!post) throw new HttpError(404, 'Post not found');
  return post;
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

function notBlockedEitherWay(viewerId: string) {
  return {
    NOT: {
      OR: [{ blocking: { some: { blockedId: viewerId } } }, { blockedBy: { some: { blockerId: viewerId } } }],
    },
  };
}

async function fetchFeedCandidates(
  postAuthorFilter: object,
  repostAuthorFilter: object,
  viewerId: string,
  kind: string | undefined,
  cursor: ReturnType<typeof decodeCursor>,
  limit: number,
): Promise<FeedCandidate[]> {
  const [postRows, repostRows] = await Promise.all([
    prisma.post.findMany({
      where: {
        ...postAuthorFilter,
        ...(kind ? { kind: kind as PostKind } : {}),
        ...buildCursorWhere(cursor),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      include: VIEWER_STATE_INCLUDE(viewerId),
    }),
    prisma.repost.findMany({
      where: {
        ...repostAuthorFilter,
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

  return [...postCandidates, ...repostCandidates].sort((a, b) => {
    const byDate = b.createdAt.getTime() - a.createdAt.getTime();
    return byDate !== 0 ? byDate : b.id.localeCompare(a.id);
  });
}

export interface FeedPage extends CursorPage<FeedItem> {
  // True when this page is the discovery fallback below rather than posts
  // from people the viewer follows — lets the client label it accordingly.
  isDiscovery: boolean;
}

// Marks a cursor as belonging to the discovery feed (see below) rather than
// the personalized one, so pagination stays in discovery mode across pages
// without re-deriving that decision from scratch on every request.
const DISCOVERY_CURSOR_PREFIX = 'discover_';

function discoveryFilter(viewerId: string) {
  return { userId: { not: viewerId }, user: notBlockedEitherWay(viewerId) };
}

export async function listFeed(
  viewerId: string,
  query: { kind?: string; cursor?: string; limit?: string },
): Promise<FeedPage> {
  const limit = parseLimit(query.limit);
  const kind = query.kind?.toUpperCase();
  if (kind && kind !== 'POST' && kind !== 'REEL') {
    throw new HttpError(400, "kind must be 'POST' or 'REEL'");
  }

  const rawCursor = query.cursor;
  const forcedDiscovery = rawCursor?.startsWith(DISCOVERY_CURSOR_PREFIX) ?? false;
  const cursor = decodeCursor(forcedDiscovery ? rawCursor!.slice(DISCOVERY_CURSOR_PREFIX.length) : rawCursor);

  let merged: FeedCandidate[] = [];
  if (!forcedDiscovery) {
    const following = await prisma.follow.findMany({ where: { followerId: viewerId }, select: { followingId: true } });
    const authorIds = [viewerId, ...following.map((f) => f.followingId)];
    merged = await fetchFeedCandidates(
      { userId: { in: authorIds } },
      { userId: { in: authorIds } },
      viewerId,
      kind,
      cursor,
      limit,
    );
  }

  // Nothing from people the viewer follows — typically a brand-new account
  // that hasn't followed anyone yet. Fall back to recent public posts, the
  // way Instagram fills a new user's feed before they follow anyone. Only
  // *enters* discovery on the true first page (no cursor); once in it,
  // `forcedDiscovery` keeps every later page there via the cursor marker.
  const isDiscovery = forcedDiscovery || (merged.length === 0 && !cursor);
  if (isDiscovery) {
    merged = await fetchFeedCandidates(discoveryFilter(viewerId), discoveryFilter(viewerId), viewerId, kind, cursor, limit);
  }

  const page = toPage(merged, limit);
  const nextCursor = page.nextCursor && isDiscovery ? `${DISCOVERY_CURSOR_PREFIX}${page.nextCursor}` : page.nextCursor;
  return { items: page.items.map((c) => c.item), nextCursor, isDiscovery };
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
