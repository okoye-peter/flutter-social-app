import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { isRecordNotFoundError } from '../lib/prisma-errors.js';
import { decodeCursor, buildCursorWhere, toPage, parseLimit, type CursorPage } from '../lib/pagination.js';
import { assertNotBlocked } from './block.js';
import { createNotification } from './notifications.js';
import type { PostAuthor } from './post.js';
import type { Comment } from '../../generated/prisma/index.js';

export const MAX_COMMENT_LENGTH = 2000;
const COMMENT_EDIT_WINDOW_MS = 15 * 60 * 1000;

export type CommentWithViewerState = Comment & { user: PostAuthor; likedByMe: boolean };

type CommentWithRawViewerState = Comment & { user: PostAuthor; likes: { id: string }[] };

const COMMENT_VIEWER_INCLUDE = (viewerId: string) => ({
  user: { select: { id: true, name: true, username: true, image: true } },
  likes: { where: { userId: viewerId }, select: { id: true } },
});

function withViewerState(comment: CommentWithRawViewerState): CommentWithViewerState {
  const { likes, ...rest } = comment;
  return { ...rest, likedByMe: likes.length > 0 };
}

export async function createComment(
  postId: string,
  userId: string,
  content: string,
  replyToId: string | undefined,
): Promise<Comment> {
  const post = await prisma.post.findUnique({ where: { id: postId }, select: { userId: true } });
  if (!post) throw new HttpError(404, 'Post not found');
  await assertNotBlocked(post.userId, userId);

  let parent: { userId: string } | null = null;
  if (replyToId) {
    parent = await prisma.comment.findUnique({
      where: { id: replyToId, postId, deletedAt: null },
      select: { userId: true },
    });
    if (!parent) throw new HttpError(404, 'Comment being replied to was not found');
  }

  const [comment] = await prisma.$transaction([
    prisma.comment.create({ data: { postId, userId, content: content.trim(), replyToId } }),
    prisma.post.update({ where: { id: postId }, data: { commentsCount: { increment: 1 } } }),
  ]);

  if (parent) {
    await createNotification({ userId: parent.userId, actorId: userId, type: 'COMMENT_REPLY', commentId: comment.id });
  } else {
    await createNotification({ userId: post.userId, actorId: userId, type: 'POST_COMMENT', postId, commentId: comment.id });
  }

  return comment;
}

export async function getComment(commentId: string): Promise<Comment> {
  const comment = await prisma.comment.findUnique({ where: { id: commentId, deletedAt: null } });
  if (!comment) throw new HttpError(404, 'Comment not found');
  return comment;
}

export async function updateComment(commentId: string, userId: string, content: string): Promise<Comment> {
  const comment = await prisma.comment.findUnique({ where: { id: commentId, deletedAt: null } });
  if (!comment) throw new HttpError(404, 'Comment not found');
  if (comment.userId !== userId) throw new HttpError(403, 'Only the comment author can edit it');
  if (Date.now() - comment.createdAt.getTime() > COMMENT_EDIT_WINDOW_MS) {
    throw new HttpError(403, 'Comments can only be edited within 15 minutes of posting');
  }

  return prisma.comment.update({ where: { id: commentId }, data: { content: content.trim() } });
}

export async function deleteComment(commentId: string, userId: string): Promise<void> {
  const comment = await prisma.comment.findUnique({ where: { id: commentId, deletedAt: null } });
  if (!comment) return; // already gone — idempotent no-op
  if (comment.userId !== userId) throw new HttpError(403, 'Only the comment author can delete it');

  try {
    await prisma.$transaction([
      prisma.comment.update({ where: { id: commentId }, data: { deletedAt: new Date() } }),
      prisma.post.update({ where: { id: comment.postId }, data: { commentsCount: { decrement: 1 } } }),
    ]);
  } catch (e) {
    if (isRecordNotFoundError(e)) return;
    throw e;
  }
}

export async function listComments(
  postId: string,
  viewerId: string,
  query: { cursor?: string; limit?: string },
): Promise<CursorPage<CommentWithViewerState>> {
  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const rows = await prisma.comment.findMany({
    where: { postId, replyToId: null, deletedAt: null, ...buildCursorWhere(cursor) },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    include: COMMENT_VIEWER_INCLUDE(viewerId),
  });

  const page = toPage(rows, limit);
  return { ...page, items: page.items.map(withViewerState) };
}

export async function listReplies(
  commentId: string,
  viewerId: string,
  query: { cursor?: string; limit?: string },
): Promise<CursorPage<CommentWithViewerState>> {
  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const rows = await prisma.comment.findMany({
    where: { replyToId: commentId, deletedAt: null, ...buildCursorWhere(cursor) },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    include: COMMENT_VIEWER_INCLUDE(viewerId),
  });

  const page = toPage(rows, limit);
  return { ...page, items: page.items.map(withViewerState) };
}
