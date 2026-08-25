import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { uploadImage } from './cloudinary.js';
import { toSafeUser, type SafeUser } from './auth.js';
import { isFollowing } from './follow.js';
import { hasBlocked } from './block.js';

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
