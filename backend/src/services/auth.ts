import { createHash, randomBytes } from 'node:crypto';
import { prisma } from '../prisma.js';
import { hashPassword, verifyPassword } from '../lib/password.js';
import { signAccessToken } from '../lib/jwt.js';
import { sendMail } from '../lib/email.js';
import { HttpError } from '../lib/http-error.js';
import { isValidEmail, isValidName, isValidPassword, isValidPhoneNumber } from '../lib/validators.js';
import { uploadImage } from './cloudinary.js';
import type { User } from '../../generated/prisma/index.js';

const RESET_TOKEN_TTL_MS = 60 * 60 * 1000;
const REFRESH_TOKEN_TTL_MS = 7 * 24 * 60 * 60 * 1000;

export type SafeUser = Omit<User, 'password'>;

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export interface RegisterInput {
  name?: string;
  email?: string;
  phoneNumber?: string;
  password?: string;
}

export interface LoginInput {
  email?: string;
  password?: string;
}

export interface UpdateProfileInput {
  name?: string;
  aboutMe?: string;
  imageFile?: { buffer: Buffer };
}

function toSafeUser(user: User): SafeUser {
  const { password: _password, ...safeUser } = user;
  return safeUser;
}

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

async function issueTokenPair(userId: string): Promise<TokenPair> {
  const refreshToken = randomBytes(32).toString('hex');
  await prisma.refreshToken.create({
    data: {
      userId,
      tokenHash: hashToken(refreshToken),
      expiresAt: new Date(Date.now() + REFRESH_TOKEN_TTL_MS),
    },
  });

  return { accessToken: signAccessToken(userId), refreshToken };
}

export async function refreshTokens(token: string | undefined): Promise<TokenPair> {
  if (!token) {
    throw new HttpError(400, 'refreshToken is required');
  }

  const stored = await prisma.refreshToken.findUnique({ where: { tokenHash: hashToken(token) } });
  if (!stored || stored.revokedAt || stored.expiresAt < new Date()) {
    throw new HttpError(401, 'Invalid or expired refresh token');
  }

  await prisma.refreshToken.update({
    where: { id: stored.id },
    data: { revokedAt: new Date() },
  });

  return issueTokenPair(stored.userId);
}

export async function logoutUser(token: string | undefined): Promise<void> {
  if (!token) {
    return;
  }

  await prisma.refreshToken.updateMany({
    where: { tokenHash: hashToken(token), revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

export async function registerUser(input: RegisterInput): Promise<{ user: SafeUser } & TokenPair> {
  const { name, email, phoneNumber, password } = input;

  if (!name || !email || !phoneNumber || !password) {
    throw new HttpError(400, 'name, email, phoneNumber and password are required');
  }
  if (!isValidName(name)) {
    throw new HttpError(400, 'Name is too short');
  }
  if (!isValidEmail(email)) {
    throw new HttpError(400, 'Enter a valid email');
  }
  if (!isValidPhoneNumber(phoneNumber)) {
    throw new HttpError(400, 'Enter a valid phone number');
  }
  if (!isValidPassword(password)) {
    throw new HttpError(400, 'Password must be at least 6 characters');
  }

  const existing = await prisma.user.findFirst({
    where: { OR: [{ email: email.trim().toLowerCase() }, { phoneNumber: phoneNumber.trim() }] },
  });
  if (existing) {
    throw new HttpError(409, 'An account with this email or phone number already exists');
  }

  const user = await prisma.user.create({
    data: {
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phoneNumber: phoneNumber.trim(),
      password: await hashPassword(password),
    },
  });

  return { user: toSafeUser(user), ...(await issueTokenPair(user.id)) };
}

export async function loginUser(input: LoginInput): Promise<{ user: SafeUser } & TokenPair> {
  const { email, password } = input;
  if (!email || !password) {
    throw new HttpError(400, 'email and password are required');
  }

  const user = await prisma.user.findUnique({ where: { email: email.trim().toLowerCase() } });
  const isValid = user ? await verifyPassword(password, user.password) : false;
  if (!user || !isValid) {
    throw new HttpError(401, 'Invalid email or password');
  }

  return { user: toSafeUser(user), ...(await issueTokenPair(user.id)) };
}

export async function getUserById(userId: string): Promise<SafeUser> {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) {
    throw new HttpError(404, 'User not found');
  }
  return toSafeUser(user);
}

export async function requestPasswordReset(email: string | undefined): Promise<void> {
  if (!email || !isValidEmail(email)) {
    throw new HttpError(400, 'Enter a valid email');
  }

  const user = await prisma.user.findUnique({ where: { email: email.trim().toLowerCase() } });
  if (user) {
    const rawToken = randomBytes(32).toString('hex');
    await prisma.passwordResetToken.create({
      data: {
        userId: user.id,
        tokenHash: hashToken(rawToken),
        expiresAt: new Date(Date.now() + RESET_TOKEN_TTL_MS),
      },
    });

    const resetUrl = process.env.RESET_PASSWORD_URL ?? 'http://localhost:3000/reset-password';
    await sendMail(
      user.email,
      'Reset your password',
      `<p>Click the link below to reset your password. This link expires in 1 hour.</p>
       <p><a href="${resetUrl}?token=${rawToken}">${resetUrl}?token=${rawToken}</a></p>`,
    );
  }
}

export async function resetPassword(token: string | undefined, newPassword: string | undefined): Promise<void> {
  if (!token || !newPassword) {
    throw new HttpError(400, 'token and newPassword are required');
  }
  if (!isValidPassword(newPassword)) {
    throw new HttpError(400, 'Password must be at least 6 characters');
  }

  const resetToken = await prisma.passwordResetToken.findUnique({ where: { tokenHash: hashToken(token) } });
  if (!resetToken || resetToken.usedAt || resetToken.expiresAt < new Date()) {
    throw new HttpError(400, 'This reset link is invalid or has expired');
  }

  await prisma.$transaction([
    prisma.user.update({
      where: { id: resetToken.userId },
      data: { password: await hashPassword(newPassword) },
    }),
    prisma.passwordResetToken.updateMany({
      where: { userId: resetToken.userId, usedAt: null },
      data: { usedAt: new Date() },
    }),
  ]);
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
