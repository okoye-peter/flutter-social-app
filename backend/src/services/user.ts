import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { uploadImage } from './cloudinary.js';
import { toSafeUser, type SafeUser } from './auth.js';
import { isFollowing } from './follow.js';
import { hasBlocked } from './block.js';
import { decodeCursor, buildCursorWhere, toPage, parseLimit, type CursorPage } from '../lib/pagination.js';

export interface UpdateProfileInput {
  name?: string;
  aboutMe?: string;
  imageFile?: { buffer: Buffer };
}

export async function updateProfile(userId: string, input: UpdateProfileInput): Promise<SafeUser> {
  const { name, aboutMe, imageFile } = input;
  const image = imageFile ? await uploadImage(imageFile.buffer, 'profile-images') : undefined;

  const user = await prisma.user.update({
    where: { id: userId },
    data: {
      ...(name !== undefined ? { name: name.trim() } : {}),
      ...(aboutMe !== undefined ? { aboutMe: aboutMe.trim() } : {}),
      ...(image !== undefined ? { image } : {}),
    },
  });

  return toSafeUser(user);
}

export async function getUserProfile(
  targetUserId: string,
  viewerId: string,
): Promise<{ user: SafeUser; isFollowedByMe: boolean; isBlockedByMe: boolean }> {
  const user = await prisma.user.findUnique({ where: { id: targetUserId } });
  if (!user) throw new HttpError(404, 'User not found');

  const [followedByMe, blockedByMe] = await Promise.all([
    isFollowing(viewerId, targetUserId),
    hasBlocked(viewerId, targetUserId),
  ]);

  return { user: toSafeUser(user), isFollowedByMe: followedByMe, isBlockedByMe: blockedByMe };
}

export interface UserSearchResult extends SafeUser {
  isFollowedByMe: boolean;
  followsMe: boolean;
}

export async function searchUsers(
  viewerId: string,
  query: { q?: string; cursor?: string; limit?: string },
): Promise<CursorPage<UserSearchResult>> {
  const q = (query.q ?? '').trim();
  if (!q) return { items: [], nextCursor: null };

  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const rows = await prisma.user.findMany({
    where: {
      id: { not: viewerId },
      AND: [
        { OR: [{ name: { contains: q, mode: 'insensitive' } }, { username: { contains: q, mode: 'insensitive' } }] },
        // Hide both directions of a block: people the viewer blocked, and
        // people who blocked the viewer.
        {
          NOT: {
            OR: [
              { blocking: { some: { blockedId: viewerId } } },
              { blockedBy: { some: { blockerId: viewerId } } },
            ],
          },
        },
        buildCursorWhere(cursor),
      ],
    },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    select: {
      id: true,
      name: true,
      username: true,
      email: true,
      phoneNumber: true,
      image: true,
      aboutMe: true,
      isOnline: true,
      fcmToken: true,
      lastSeen: true,
      followersCount: true,
      followingCount: true,
      postsCount: true,
      createdAt: true,
      updatedAt: true,
    },
  });

  const page = toPage(rows, limit);
  const ids = page.items.map((u) => u.id);

  // One query for both directions instead of 2*N per-row lookups.
  const follows = await prisma.follow.findMany({
    where: {
      OR: [
        { followerId: viewerId, followingId: { in: ids } },
        { followingId: viewerId, followerId: { in: ids } },
      ],
    },
    select: { followerId: true, followingId: true },
  });
  const followedByMeIds = new Set(follows.filter((f) => f.followerId === viewerId).map((f) => f.followingId));
  const followsMeIds = new Set(follows.filter((f) => f.followingId === viewerId).map((f) => f.followerId));

  return {
    items: page.items.map((user) => ({
      ...toSafeUser(user),
      isFollowedByMe: followedByMeIds.has(user.id),
      followsMe: followsMeIds.has(user.id),
    })),
    nextCursor: page.nextCursor,
  };
}
