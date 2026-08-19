import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { isUniqueConstraintError, isRecordNotFoundError } from '../lib/prisma-errors.js';
import { decodeCursor, buildCursorWhere, toPage, parseLimit, type CursorPage } from '../lib/pagination.js';
import { assertNotBlocked } from './block.js';
import type { Post } from '../../generated/prisma/index.js';

export async function bookmarkPost(postId: string, userId: string): Promise<{ bookmarksCount: number }> {
  const post = await prisma.post.findUnique({ where: { id: postId }, select: { userId: true } });
  if (!post) throw new HttpError(404, 'Post not found');
  await assertNotBlocked(post.userId, userId);

  try {
    const updated = await prisma.$transaction(async (tx) => {
      await tx.bookmark.create({ data: { postId, userId } });
      return tx.post.update({ where: { id: postId }, data: { bookmarksCount: { increment: 1 } } });
    });
    return { bookmarksCount: updated.bookmarksCount };
  } catch (e) {
    if (isUniqueConstraintError(e)) {
      const p = await prisma.post.findUniqueOrThrow({ where: { id: postId }, select: { bookmarksCount: true } });
      return { bookmarksCount: p.bookmarksCount }; // already bookmarked — idempotent no-op
    }
    throw e;
  }
}

export async function unbookmarkPost(postId: string, userId: string): Promise<{ bookmarksCount: number }> {
  try {
    const updated = await prisma.$transaction(async (tx) => {
      await tx.bookmark.delete({ where: { postId_userId: { postId, userId } } });
      return tx.post.update({ where: { id: postId }, data: { bookmarksCount: { decrement: 1 } } });
    });
    return { bookmarksCount: updated.bookmarksCount };
  } catch (e) {
    if (isRecordNotFoundError(e)) {
      const p = await prisma.post.findUnique({ where: { id: postId }, select: { bookmarksCount: true } });
      if (!p) throw new HttpError(404, 'Post not found');
      return { bookmarksCount: p.bookmarksCount }; // not bookmarked — idempotent no-op
    }
    throw e;
  }
}

export async function listBookmarks(
  userId: string,
  query: { cursor?: string; limit?: string },
): Promise<CursorPage<Post>> {
  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const rows = await prisma.bookmark.findMany({
    where: { userId, ...buildCursorWhere(cursor) },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    include: { post: true },
  });

  const page = toPage(rows, limit);
  return { items: page.items.map((row) => row.post), nextCursor: page.nextCursor };
}
