import { z } from 'zod';
import {
  isValidEmail,
  isValidName,
  isValidPassword,
  isValidPhoneNumber,
  isValidUsername,
} from '../lib/validators.js';

export const registerSchema = z
  .object({
    name: z.string().optional(),
    username: z.string().optional(),
    email: z.string().optional(),
    phoneNumber: z.string().optional(),
    password: z.string().optional(),
  })
  .superRefine((data, ctx) => {
    const { name, username, email, phoneNumber, password } = data;
    if (!name || !username || !email || !phoneNumber || !password) {
      ctx.addIssue('name, username, email, phoneNumber and password are required');
      return;
    }
    if (!isValidName(name)) {
      ctx.addIssue('Name is too short');
      return;
    }
    if (!isValidUsername(username)) {
      ctx.addIssue('3-20 characters: letters, numbers, underscore only');
      return;
    }
    if (!isValidEmail(email)) {
      ctx.addIssue('Enter a valid email');
      return;
    }
    if (!isValidPhoneNumber(phoneNumber)) {
      ctx.addIssue('Enter a valid phone number');
      return;
    }
    if (!isValidPassword(password)) {
      ctx.addIssue('Password must be at least 6 characters');
    }
  });

export const loginSchema = z
  .object({ email: z.string().optional(), password: z.string().optional() })
  .superRefine((data, ctx) => {
    if (!data.email || !data.password) {
      ctx.addIssue('email and password are required');
    }
  });

export const refreshSchema = z
  .object({ refreshToken: z.string().optional() })
  .superRefine((data, ctx) => {
    if (!data.refreshToken) {
      ctx.addIssue('refreshToken is required');
    }
  });

export const forgotPasswordSchema = z
  .object({ email: z.string().optional() })
  .superRefine((data, ctx) => {
    if (!data.email || !isValidEmail(data.email)) {
      ctx.addIssue('Enter a valid email');
    }
  });

export const resetPasswordSchema = z
  .object({ token: z.string().optional(), newPassword: z.string().optional() })
  .superRefine((data, ctx) => {
    if (!data.token || !data.newPassword) {
      ctx.addIssue('token and newPassword are required');
      return;
    }
    if (!isValidPassword(data.newPassword)) {
      ctx.addIssue('Password must be at least 6 characters');
    }
  });

export const sendEmailOtpSchema = z
  .object({ email: z.string().optional() })
  .superRefine((data, ctx) => {
    if (!data.email) ctx.addIssue('email is required');
  });

export const verifyEmailOtpSchema = z
  .object({ email: z.string().optional(), code: z.string().optional() })
  .superRefine((data, ctx) => {
    if (!data.email) ctx.addIssue('email is required');
  });

export const sendPhoneOtpSchema = z
  .object({ phoneNumber: z.string().optional() })
  .superRefine((data, ctx) => {
    if (!data.phoneNumber) ctx.addIssue('phoneNumber is required');
  });

export const verifyPhoneOtpSchema = z
  .object({ phoneNumber: z.string().optional(), code: z.string().optional() })
  .superRefine((data, ctx) => {
    if (!data.phoneNumber) ctx.addIssue('phoneNumber is required');
  });
