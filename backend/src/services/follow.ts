import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { isUniqueConstraintError, isRecordNotFoundError } from '../lib/prisma-errors.js';
import { decodeCursor, buildCursorWhere, toPage, parseLimit, type CursorPage } from '../lib/pagination.js';
import { assertNotBlocked } from './block.js';
import { createNotification } from './notifications.js';
import { toSafeUser, type SafeUser } from './auth.js';
import type { User } from '../../generated/prisma/index.js';

export async function followUser(followerId: string, followingId: string): Promise<{ followersCount: number }> {
  if (followerId === followingId) {
    throw new HttpError(400, 'You cannot follow yourself');
  }
  const target = await prisma.user.findUnique({ where: { id: followingId }, select: { id: true } });
  if (!target) throw new HttpError(404, 'User not found');
  await assertNotBlocked(followerId, followingId);

  try {
    const [, target] = await prisma.$transaction([
      prisma.follow.create({ data: { followerId, followingId } }),
      prisma.user.update({ where: { id: followingId }, data: { followersCount: { increment: 1 } } }),
      prisma.user.update({ where: { id: followerId }, data: { followingCount: { increment: 1 } } }),
    ]);

    await createNotification({ userId: followingId, actorId: followerId, type: 'FOLLOW' });
    return { followersCount: (target as User).followersCount };
  } catch (e) {
    if (isUniqueConstraintError(e)) {
      const target = await prisma.user.findUniqueOrThrow({ where: { id: followingId }, select: { followersCount: true } });
      return { followersCount: target.followersCount }; // already following — idempotent no-op
    }
    throw e;
  }
}

export async function unfollowUser(followerId: string, followingId: string): Promise<{ followersCount: number }> {
  try {
    const [, target] = await prisma.$transaction([
      prisma.follow.delete({ where: { followerId_followingId: { followerId, followingId } } }),
      prisma.user.update({ where: { id: followingId }, data: { followersCount: { decrement: 1 } } }),
      prisma.user.update({ where: { id: followerId }, data: { followingCount: { decrement: 1 } } }),
    ]);
    return { followersCount: (target as User).followersCount };
  } catch (e) {
    if (isRecordNotFoundError(e)) {
      const target = await prisma.user.findUniqueOrThrow({ where: { id: followingId }, select: { followersCount: true } });
      return { followersCount: target.followersCount }; // not following — idempotent no-op
    }
    throw e;
  }
}

export async function isFollowing(followerId: string, followingId: string): Promise<boolean> {
  const follow = await prisma.follow.findUnique({
    where: { followerId_followingId: { followerId, followingId } },
    select: { id: true },
  });
  return follow !== null;
}

export async function listFollowers(
  followingId: string,
  query: { cursor?: string; limit?: string },
): Promise<CursorPage<SafeUser>> {
  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const rows = await prisma.follow.findMany({
    where: { followingId, ...buildCursorWhere(cursor) },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    include: { follower: true },
  });

  const page = toPage(rows, limit);
  return { items: page.items.map((row) => toSafeUser(row.follower)), nextCursor: page.nextCursor };
}

export async function listFollowing(
  followerId: string,
  query: { cursor?: string; limit?: string },
): Promise<CursorPage<SafeUser>> {
  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const rows = await prisma.follow.findMany({
    where: { followerId, ...buildCursorWhere(cursor) },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    include: { following: true },
  });

  const page = toPage(rows, limit);
  return { items: page.items.map((row) => toSafeUser(row.following)), nextCursor: page.nextCursor };
}
