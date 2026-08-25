import { z } from 'zod';

export const registerTokenSchema = z
  .object({ userId: z.string().optional(), token: z.string().optional() })
  .superRefine((data, ctx) => {
    if (!data.userId || !data.token) {
      ctx.addIssue('userId and token are required');
    }
  });

export const sendNotificationSchema = z
  .object({
    userId: z.string().optional(),
    title: z.string().optional(),
    body: z.string().optional(),
    data: z.record(z.string(), z.string()).optional(),
  })
  .superRefine((data, ctx) => {
    if (!data.userId || !data.title || !data.body) {
      ctx.addIssue('userId, title and body are required');
    }
  });
