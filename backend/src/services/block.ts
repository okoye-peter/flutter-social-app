import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { isUniqueConstraintError, isRecordNotFoundError } from '../lib/prisma-errors.js';
import { decodeCursor, buildCursorWhere, toPage, parseLimit, type CursorPage } from '../lib/pagination.js';
import { toSafeUser, type SafeUser } from './auth.js';

export async function isBlocked(userAId: string, userBId: string): Promise<boolean> {
  const block = await prisma.block.findFirst({
    where: {
      OR: [
        { blockerId: userAId, blockedId: userBId },
        { blockerId: userBId, blockedId: userAId },
      ],
    },
    select: { id: true },
  });
  return block !== null;
}

export async function hasBlocked(blockerId: string, blockedId: string): Promise<boolean> {
  const block = await prisma.block.findUnique({
    where: { blockerId_blockedId: { blockerId, blockedId } },
    select: { id: true },
  });
  return block !== null;
}

export async function assertNotBlocked(userAId: string, userBId: string): Promise<void> {
  if (userAId === userBId) return;
  if (await isBlocked(userAId, userBId)) {
    throw new HttpError(403, 'This action is not available');
  }
}

export async function blockUser(blockerId: string, blockedId: string): Promise<void> {
  if (blockerId === blockedId) {
    throw new HttpError(400, 'You cannot block yourself');
  }

  try {
    await prisma.$transaction(async (tx) => {
      await tx.block.create({ data: { blockerId, blockedId } });

      // A stale follow across a fresh block is a correctness bug, not just a
      // UX nicety — sever it both ways and keep the counters honest.
      const stale = await tx.follow.findMany({
        where: {
          OR: [
            { followerId: blockerId, followingId: blockedId },
            { followerId: blockedId, followingId: blockerId },
          ],
        },
      });
      for (const follow of stale) {
        await tx.follow.delete({ where: { id: follow.id } });
        await tx.user.update({ where: { id: follow.followerId }, data: { followingCount: { decrement: 1 } } });
        await tx.user.update({ where: { id: follow.followingId }, data: { followersCount: { decrement: 1 } } });
      }
    });
  } catch (e) {
    if (isUniqueConstraintError(e)) return; // already blocked — idempotent no-op
    throw e;
  }
}

export async function unblockUser(blockerId: string, blockedId: string): Promise<void> {
  try {
    await prisma.block.delete({ where: { blockerId_blockedId: { blockerId, blockedId } } });
  } catch (e) {
    if (isRecordNotFoundError(e)) return; // not blocked — idempotent no-op
    throw e;
  }
}

export async function listBlocked(
  blockerId: string,
  query: { cursor?: string; limit?: string },
): Promise<CursorPage<SafeUser>> {
  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const rows = await prisma.block.findMany({
    where: { blockerId, ...buildCursorWhere(cursor) },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    include: { blocked: true },
  });

  const page = toPage(rows, limit);
  return { items: page.items.map((row) => toSafeUser(row.blocked)), nextCursor: page.nextCursor };
}
