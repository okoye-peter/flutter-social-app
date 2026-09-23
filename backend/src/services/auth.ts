import { randomBytes, randomInt } from 'node:crypto';
import { prisma } from '../prisma.js';
import { hashPassword, verifyPassword } from '../lib/password.js';
import { hashToken } from '../lib/hash.js';
import { signAccessToken } from '../lib/jwt.js';
import { sendMail } from '../lib/email.js';
import { HttpError } from '../lib/http-error.js';
import { uploadImage } from './cloudinary.js';
import { assertVerified, clearVerified } from './otp.js';
import type { User } from '../../generated/prisma/index.js';

// How long a password-reset code stays valid. Kept short (10 min) since a
// leaked/intercepted code is a real attack window — long TTLs give an
// attacker more time to use a code they shouldn't have. Mirrors otp.ts's
// own OTP_TTL_MS/MAX_ATTEMPTS — this uses the same `Otp` table (channel:
// PASSWORD_RESET) rather than otp.ts's sendOtp/verifyOtp directly, since
// those enforce the opposite existence check (registration requires the
// identifier NOT already belong to an account; password reset requires
// that it DOES).
const RESET_CODE_TTL_MS = 10 * 60 * 1000;
const RESET_MAX_ATTEMPTS = 5;

function generateResetCode(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, '0');
}

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

export function toSafeUser(user: SafeUser & { password?: unknown }): SafeUser {
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
  const normalizedEmail = email.trim().toLowerCase();
  const user = await prisma.user.findUnique({ where: { email: normalizedEmail } });
  // Same response either way at the controller level — don't leak whether
  // an account exists for this email.
  if (!user) return;

  const code = generateResetCode();
  // Drop any still-pending code so only the latest one sent is ever valid,
  // same as otp.ts's sendOtp.
  await prisma.otp.deleteMany({ where: { identifier: normalizedEmail, channel: 'PASSWORD_RESET', verifiedAt: null } });
  await prisma.otp.create({
    data: {
      identifier: normalizedEmail,
      channel: 'PASSWORD_RESET',
      codeHash: hashToken(code),
      expiresAt: new Date(Date.now() + RESET_CODE_TTL_MS),
    },
  });

  await sendMail(
    user.email,
    'Reset your password',
    `<p>Your password reset code is <strong>${code}</strong>. It expires in 10 minutes.</p>`,
  );
}

export async function resetPassword(email: string, code: string, newPassword: string): Promise<void> {
  const normalizedEmail = email.trim().toLowerCase();
  const otp = await prisma.otp.findFirst({
    where: { identifier: normalizedEmail, channel: 'PASSWORD_RESET', verifiedAt: null },
    orderBy: { createdAt: 'desc' },
  });

  if (!otp || otp.expiresAt < new Date()) {
    throw new HttpError(400, 'This code is invalid or has expired');
  }
  if (otp.attempts >= RESET_MAX_ATTEMPTS) {
    throw new HttpError(429, 'Too many attempts, request a new code');
  }
  if (hashToken(code) !== otp.codeHash) {
    await prisma.otp.update({ where: { id: otp.id }, data: { attempts: { increment: 1 } } });
    throw new HttpError(400, 'Invalid code');
  }

  const user = await prisma.user.findUnique({ where: { email: normalizedEmail } });
  if (!user) {
    throw new HttpError(400, 'This code is invalid or has expired');
  }

  await prisma.$transaction([
    prisma.user.update({ where: { id: user.id }, data: { password: await hashPassword(newPassword) } }),
    prisma.otp.update({ where: { id: otp.id }, data: { verifiedAt: new Date() } }),
  ]);
}
