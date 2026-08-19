import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { isUniqueConstraintError, isRecordNotFoundError } from '../lib/prisma-errors.js';
import { decodeCursor, buildCursorWhere, toPage, parseLimit, type CursorPage } from '../lib/pagination.js';
import { assertNotBlocked } from './block.js';
import { createNotification } from './notifications.js';
import type { PostTag, Post } from '../../generated/prisma/index.js';

const MAX_TAGS_PER_POST = 20;

export async function addTags(postId: string, ownerId: string, userIds: string[]): Promise<PostTag[]> {
  if (!Array.isArray(userIds) || userIds.length === 0) {
    throw new HttpError(400, 'userIds is required');
  }
  if (userIds.length > MAX_TAGS_PER_POST) {
    throw new HttpError(400, `You can tag at most ${MAX_TAGS_PER_POST} people`);
  }

  const post = await prisma.post.findUnique({ where: { id: postId }, select: { userId: true } });
  if (!post) throw new HttpError(404, 'Post not found');
  if (post.userId !== ownerId) throw new HttpError(403, 'Only the post owner can tag people');

  const uniqueUserIds = [...new Set(userIds)].filter((id) => id !== ownerId);
  const existingUsers = await prisma.user.findMany({ where: { id: { in: uniqueUserIds } }, select: { id: true } });
  const existingUserIds = new Set(existingUsers.map((u) => u.id));

  const tags: PostTag[] = [];
  for (const userId of uniqueUserIds) {
    if (!existingUserIds.has(userId)) continue;
    await assertNotBlocked(ownerId, userId);
    try {
      const tag = await prisma.postTag.create({ data: { postId, userId } });
      tags.push(tag);
      await createNotification({ userId, actorId: ownerId, type: 'TAG', postId });
    } catch (e) {
      if (isUniqueConstraintError(e)) continue; // already tagged — idempotent no-op
      throw e;
    }
  }

  return tags;
}

export async function removeTag(postId: string, ownerId: string, userId: string): Promise<void> {
  const post = await prisma.post.findUnique({ where: { id: postId }, select: { userId: true } });
  if (!post) throw new HttpError(404, 'Post not found');
  if (post.userId !== ownerId) throw new HttpError(403, 'Only the post owner can remove tags');

  try {
    await prisma.postTag.delete({ where: { postId_userId: { postId, userId } } });
  } catch (e) {
    if (isRecordNotFoundError(e)) return; // not tagged — idempotent no-op
    throw e;
  }
}

export async function listTagged(
  userId: string,
  query: { cursor?: string; limit?: string },
): Promise<CursorPage<Post>> {
  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const rows = await prisma.postTag.findMany({
    where: { userId, ...buildCursorWhere(cursor) },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    include: { post: true },
  });

  const page = toPage(rows, limit);
  return { items: page.items.map((row) => row.post), nextCursor: page.nextCursor };
}
