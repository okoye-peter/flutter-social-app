import type { Request } from 'express';
import { z } from 'zod';
import { HttpError } from '../lib/http-error.js';
import { MAX_CAPTION_LENGTH } from '../services/post.js';
import { MAX_TAGS_PER_POST } from '../services/tag.js';
import { optionalJsonStringArray, optionalString } from './shared.js';

const POST_KINDS = new Set(['POST', 'REEL']);

export const createPostSchema = z
  .object({
    kind: optionalString(),
    caption: optionalString(),
    soundId: optionalString(),
    taggedUserIds: optionalJsonStringArray('taggedUserIds'),
  })
  .superRefine((data, ctx) => {
    if (data.kind !== undefined && !POST_KINDS.has(data.kind.toUpperCase())) {
      ctx.addIssue("kind must be 'POST' or 'REEL'");
    }
  });

export type CreatePostData = z.infer<typeof createPostSchema>;

// The caption/media presence check, the caption length check, and the
// video+soundId conflict all depend on req.file, which a body-only zod
// schema can't see — mirrors validate-post.ts's original logic exactly.
export function checkCreatePostFile(req: Request, data: CreatePostData) {
  const trimmedCaption = data.caption?.trim() ?? '';
  if (!trimmedCaption && !req.file) {
    throw new HttpError(400, 'A post needs a caption or media');
  }
  if (trimmedCaption.length > MAX_CAPTION_LENGTH) {
    throw new HttpError(400, `Caption must be at most ${MAX_CAPTION_LENGTH} characters`);
  }
  if (data.soundId && req.file?.mimetype.startsWith('video/')) {
    throw new HttpError(400, 'Video posts use their own audio and cannot attach a sound');
  }
}

export const repostSchema = z.object({ comment: optionalString() });

export const addTagsSchema = z
  .object({ userIds: z.array(z.string()).optional().nullable() })
  .superRefine((data, ctx) => {
    if (!data.userIds || data.userIds.length === 0) {
      ctx.addIssue('userIds is required');
      return;
    }
    if (data.userIds.length > MAX_TAGS_PER_POST) {
      ctx.addIssue(`You can tag at most ${MAX_TAGS_PER_POST} people`);
    }
  });
