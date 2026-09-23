import { z } from 'zod';
import { optionalString } from './shared.js';
import { MAX_COMMENT_LENGTH } from '../services/comment.js';

function checkContent(content: string | undefined, ctx: z.RefinementCtx) {
  if (!content || !content.trim()) {
    ctx.addIssue('content is required');
    return;
  }
  if (content.length > MAX_COMMENT_LENGTH) {
    ctx.addIssue(`Comment must be at most ${MAX_COMMENT_LENGTH} characters`);
  }
}

export const createCommentSchema = z
  .object({ content: optionalString(), replyToId: optionalString() })
  .superRefine((data, ctx) => checkContent(data.content, ctx));

export const updateCommentSchema = z
  .object({ content: optionalString() })
  .superRefine((data, ctx) => checkContent(data.content, ctx));
