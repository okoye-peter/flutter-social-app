import { z } from 'zod';
import { isValidName } from '../lib/validators.js';

// aboutMe intentionally has no length cap — none exists today either.
export const updateProfileSchema = z
  .object({ name: z.string().optional(), aboutMe: z.string().optional() })
  .superRefine((data, ctx) => {
    if (data.name !== undefined && !isValidName(data.name)) {
      ctx.addIssue('Name is too short');
    }
  });
