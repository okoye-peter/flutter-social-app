import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { isValidName } from '../lib/validators.js';
import { uploadImage } from './cloudinary.js';
import { toSafeUser, type SafeUser } from './auth.js';

export interface UpdateProfileInput {
  name?: string;
  aboutMe?: string;
  imageFile?: { buffer: Buffer };
}

export async function updateProfile(userId: string, input: UpdateProfileInput): Promise<SafeUser> {
  const { name, aboutMe, imageFile } = input;
  if (name !== undefined && !isValidName(name)) {
    throw new HttpError(400, 'Name is too short');
  }

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
