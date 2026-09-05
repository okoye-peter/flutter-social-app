import { z } from 'zod';
import { optionalString } from './shared.js';
import { isValidName } from '../lib/validators.js';

// aboutMe intentionally has no length cap — none exists today either.
export const updateProfileSchema = z
  .object({ name: optionalString(), aboutMe: optionalString() })
  .superRefine((data, ctx) => {
    if (data.name !== undefined && !isValidName(data.name)) {
      ctx.addIssue('Name is too short');
    }
  });
