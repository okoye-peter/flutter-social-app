import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { isUniqueConstraintError, isRecordNotFoundError } from '../lib/prisma-errors.js';
import { decodeCursor, buildCursorWhere, toPage, parseLimit, type CursorPage } from '../lib/pagination.js';
import { assertNotBlocked } from './block.js';
import { createNotification } from './notifications.js';
import { VIEWER_STATE_INCLUDE, withViewerState, type PostWithViewerState } from './post-view-state.js';
import type { Repost } from '../../generated/prisma/index.js';

export async function repost(
  postId: string,
  userId: string,
  comment: string | undefined,
): Promise<{ repost: Repost; repostsCount: number }> {
  const post = await prisma.post.findUnique({ where: { id: postId }, select: { userId: true } });
  if (!post) throw new HttpError(404, 'Post not found');
  await assertNotBlocked(post.userId, userId);

  try {
    const [created, updated] = await prisma.$transaction([
      prisma.repost.create({ data: { postId, userId, comment: comment?.trim() || undefined } }),
      prisma.post.update({ where: { id: postId }, data: { repostsCount: { increment: 1 } } }),
    ]);
    await createNotification({ userId: post.userId, actorId: userId, type: 'REPOST', postId });
    return { repost: created, repostsCount: updated.repostsCount };
  } catch (e) {
    if (isUniqueConstraintError(e)) {
      // already reposted — idempotent no-op, return the existing repost as-is
      const [existing, p] = await Promise.all([
        prisma.repost.findUniqueOrThrow({ where: { postId_userId: { postId, userId } } }),
        prisma.post.findUniqueOrThrow({ where: { id: postId }, select: { repostsCount: true } }),
      ]);
      return { repost: existing, repostsCount: p.repostsCount };
    }
    throw e;
  }
}

export async function unrepost(postId: string, userId: string): Promise<{ repostsCount: number }> {
  try {
    const updated = await prisma.$transaction(async (tx) => {
      await tx.repost.delete({ where: { postId_userId: { postId, userId } } });
      return tx.post.update({ where: { id: postId }, data: { repostsCount: { decrement: 1 } } });
    });
    return { repostsCount: updated.repostsCount };
  } catch (e) {
    if (isRecordNotFoundError(e)) {
      const p = await prisma.post.findUnique({ where: { id: postId }, select: { repostsCount: true } });
      if (!p) throw new HttpError(404, 'Post not found');
      return { repostsCount: p.repostsCount }; // not reposted — idempotent no-op
    }
    throw e;
  }
}

export async function listReposts(
  userId: string,
  viewerId: string,
  query: { cursor?: string; limit?: string },
): Promise<CursorPage<PostWithViewerState>> {
  await assertNotBlocked(userId, viewerId);

  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const rows = await prisma.repost.findMany({
    where: { userId, ...buildCursorWhere(cursor) },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    include: { post: { include: VIEWER_STATE_INCLUDE(viewerId) } },
  });

  const page = toPage(rows, limit);
  return { items: page.items.map((row) => withViewerState(row.post)), nextCursor: page.nextCursor };
}
