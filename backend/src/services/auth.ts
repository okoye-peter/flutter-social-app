import { randomBytes } from 'node:crypto';
import { prisma } from '../prisma.js';
import { hashPassword, verifyPassword } from '../lib/password.js';
import { hashToken } from '../lib/hash.js';
import { signAccessToken } from '../lib/jwt.js';
import { sendMail } from '../lib/email.js';
import { HttpError } from '../lib/http-error.js';
import { uploadImage } from './cloudinary.js';
import { assertVerified, clearVerified } from './otp.js';
import type { User } from '../../generated/prisma/index.js';

// How long a password-reset link stays valid. Kept short (10 min) since a
// leaked or forwarded reset email is a real attack window — long TTLs give
// an attacker more time to use a token they shouldn't have.
const RESET_TOKEN_TTL_MS = 10 * 60 * 1000;

// How long a refresh token stays valid before the user has to log in again.
// Much longer than the reset token on purpose: it's issued straight to the
// user's own device after they've already authenticated, not sent over
// email, so the leak risk it's guarding against is different.
const REFRESH_TOKEN_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

export type SafeUser = Omit<User, 'password'>;

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export interface RegisterInput {
  name: string;
  username: string;
  email: string;
  phoneNumber: string;
  password: string;
  imageFile?: { buffer: Buffer };
}

export interface LoginInput {
  email: string;
  password: string;
}

export function toSafeUser(user: User): SafeUser {
  const { password: _password, ...safeUser } = user;
  return safeUser;
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

export async function refreshTokens(token: string): Promise<TokenPair> {
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
  const { name, username, email, phoneNumber, password, imageFile } = input;

  const normalizedEmail = email.trim().toLowerCase();
  const normalizedPhone = phoneNumber.trim();
  const normalizedUsername = username.trim();

  // Email and phone must already be OTP-verified before an account can be
  // created with them — this is what the mobile registration flow's
  // verification steps are actually gating.
  await assertVerified(normalizedEmail, 'EMAIL');
  await assertVerified(normalizedPhone, 'PHONE');

  // Checked separately (not just OR'd into one query) so the error can name
  // the specific field that's taken — username especially, since that's
  // the one thing the user can immediately fix by choosing another value,
  // unlike email/phone which they can't just retype.
  const existing = await prisma.user.findFirst({
    where: {
      OR: [{ email: normalizedEmail }, { phoneNumber: normalizedPhone }, { username: normalizedUsername }],
    },
    select: { email: true, phoneNumber: true, username: true },
  });
  if (existing) {
    if (existing.username === normalizedUsername) {
      throw new HttpError(409, 'This username is already taken, please choose another one');
    }
    if (existing.email === normalizedEmail) {
      throw new HttpError(409, 'An account with this email already exists');
    }
    throw new HttpError(409, 'An account with this phone number already exists');
  }

  const image = imageFile ? await uploadImage(imageFile.buffer, 'profile-images') : undefined;

  const user = await prisma.user.create({
    data: {
      name: name.trim(),
      username: normalizedUsername,
      email: normalizedEmail,
      phoneNumber: normalizedPhone,
      password: await hashPassword(password),
      ...(image !== undefined ? { image } : {}),
    },
  });

  await clearVerified(normalizedEmail, 'EMAIL');
  await clearVerified(normalizedPhone, 'PHONE');

  return { user: toSafeUser(user), ...(await issueTokenPair(user.id)) };
}

export async function loginUser(input: LoginInput): Promise<{ user: SafeUser } & TokenPair> {
  const { email, password } = input;
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

export async function requestPasswordReset(email: string): Promise<void> {
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

export async function resetPassword(token: string, newPassword: string): Promise<void> {
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
