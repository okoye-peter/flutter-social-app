import { randomInt } from 'node:crypto';
import { prisma } from '../prisma.js';
import { hashToken } from '../lib/hash.js';
import { sendMail } from '../lib/email.js';
import { sendSms } from '../lib/sms.js';
import { HttpError } from '../lib/http-error.js';
import type { OtpChannel } from '../../generated/prisma/index.js';

const OTP_TTL_MS = 10 * 60 * 1000;
const MAX_ATTEMPTS = 5;

function generateCode(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, '0');
}

export async function sendOtp(identifier: string, channel: OtpChannel): Promise<void> {
  // Reject up front if this identifier already belongs to a completed
  // account, rather than letting the user go through the whole
  // email/phone verification flow only to be rejected at the final
  // registration step.
  const existingUser = await prisma.user.findFirst({
    where: channel === 'EMAIL' ? { email: identifier } : { phoneNumber: identifier },
  });
  if (existingUser) {
    const label = channel === 'EMAIL' ? 'email' : 'phone number';
    throw new HttpError(409, `An account with this ${label} already exists`);
  }

  const code = generateCode();

  // Drop any still-pending code for this identifier/channel so only the
  // latest one sent is ever valid.
  await prisma.otp.deleteMany({ where: { identifier, channel, verifiedAt: null } });
  await prisma.otp.create({
    data: {
      identifier,
      channel,
      codeHash: hashToken(code),
      expiresAt: new Date(Date.now() + OTP_TTL_MS),
    },
  });

  const message = `Your verification code is ${code}. It expires in 10 minutes.`;
  if (channel === 'EMAIL') {
    await sendMail(identifier, 'Verify your email', `<p>${message}</p>`);
  } else {
    await sendSms(identifier, message);
  }
}

export async function verifyOtp(identifier: string, channel: OtpChannel, code: string | undefined): Promise<void> {
  if (!code) {
    throw new HttpError(400, 'Enter the verification code');
  }

  const otp = await prisma.otp.findFirst({
    where: { identifier, channel, verifiedAt: null },
    orderBy: { createdAt: 'desc' },
  });

  if (!otp) {
    throw new HttpError(400, 'Request a new verification code');
  }
  if (otp.expiresAt < new Date()) {
    throw new HttpError(400, 'This code has expired, request a new one');
  }
  if (otp.attempts >= MAX_ATTEMPTS) {
    throw new HttpError(429, 'Too many attempts, request a new code');
  }

  if (hashToken(code) !== otp.codeHash) {
    await prisma.otp.update({ where: { id: otp.id }, data: { attempts: { increment: 1 } } });
    throw new HttpError(400, 'Invalid verification code');
  }

  await prisma.otp.update({ where: { id: otp.id }, data: { verifiedAt: new Date() } });
}

/// Throws unless `identifier` has a verified OTP on record for `channel` —
/// used to gate account creation on the mobile app's verification steps
/// actually having happened.
export async function assertVerified(identifier: string, channel: OtpChannel): Promise<void> {
  const verified = await prisma.otp.findFirst({
    where: { identifier, channel, verifiedAt: { not: null } },
  });

  if (!verified) {
    const label = channel === 'EMAIL' ? 'Email' : 'Phone number';
    throw new HttpError(400, `${label} has not been verified`);
  }
}

export async function clearVerified(identifier: string, channel: OtpChannel): Promise<void> {
  await prisma.otp.deleteMany({ where: { identifier, channel } });
}
