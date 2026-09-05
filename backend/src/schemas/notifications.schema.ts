import { z } from 'zod';
import { optionalString } from './shared.js';

// userId isn't part of either body — both routes act on the authenticated
// caller (req.userId), never a client-supplied id.
export const registerTokenSchema = z
  .object({ token: optionalString() })
  .superRefine((data, ctx) => {
    if (!data.token) {
      ctx.addIssue('token is required');
    }
  });

export const sendNotificationSchema = z
  .object({
    title: optionalString(),
    body: optionalString(),
    data: z
      .record(z.string(), z.string())
      .optional()
      .nullable()
      .transform((value) => value ?? undefined),
  })
  .superRefine((data, ctx) => {
    if (!data.title || !data.body) {
      ctx.addIssue('title and body are required');
    }
  });
