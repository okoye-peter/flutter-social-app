import type { Request } from 'express';
import { z } from 'zod';
import { HttpError } from '../lib/http-error.js';
import { MAX_CAPTION_LENGTH } from '../services/story.js';
import { optionalString } from './shared.js';

export const createStorySchema = z
  .object({ caption: optionalString() })
  .superRefine((data, ctx) => {
    const trimmedCaption = data.caption?.trim() ?? '';
    if (trimmedCaption.length > MAX_CAPTION_LENGTH) {
      ctx.addIssue(`Caption must be at most ${MAX_CAPTION_LENGTH} characters`);
    }
  });

// Standardizes what used to be a direct res.status(400).json(...) in the
// controller back to the HttpError/errorHandler convention used everywhere
// else in the app.
export function checkCreateStoryFileRequired(req: Request) {
  if (!req.file) {
    throw new HttpError(400, 'A story needs image or video media');
  }
}
