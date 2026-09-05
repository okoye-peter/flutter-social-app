import type { Request } from 'express';
import { z } from 'zod';
import { HttpError } from '../lib/http-error.js';
import { MessageType } from '../../generated/prisma/index.js';
import { MAX_CONTENT_LENGTH } from '../services/message.js';
import { MAX_EMOJI_LENGTH } from '../services/reaction.js';
import { optionalJsonStringArray, optionalString } from './shared.js';

// SYSTEM is deliberately excluded — those are only ever created internally
// (see conversation.ts's postSystemMessage), never client-submitted.
const VALID_TYPES = Object.values(MessageType).filter((type) => type !== 'SYSTEM');

export const sendMessageSchema = z.object({
  type: optionalString(),
  content: optionalString(),
  replyToId: optionalString(),
  mentionedUserIds: optionalJsonStringArray('mentionedUserIds'),
  durationSeconds: optionalString(),
});

export type SendMessageData = z.infer<typeof sendMessageSchema>;

// Mirrors services/message.ts's original checks verbatim. This can't be a
// pure body schema: the type default, the content-required rule, and the
// mimetype cross-check all depend on req.file, which zod can't see.
export function checkSendMessageFile(req: Request, data: SendMessageData) {
  const resolvedType = (data.type ?? (req.file ? 'FILE' : 'TEXT')).toUpperCase();
  if (!VALID_TYPES.includes(resolvedType as (typeof VALID_TYPES)[number])) {
    throw new HttpError(400, `type must be one of: ${VALID_TYPES.join(', ')}`);
  }

  const trimmedContent = data.content?.trim() || undefined;
  if (resolvedType === 'TEXT' && !trimmedContent) {
    throw new HttpError(400, 'content is required for a text message');
  }
  if (trimmedContent && trimmedContent.length > MAX_CONTENT_LENGTH) {
    throw new HttpError(400, `Message must be at most ${MAX_CONTENT_LENGTH} characters`);
  }
  if (resolvedType !== 'TEXT' && !req.file) {
    throw new HttpError(400, `A file is required for type ${resolvedType}`);
  }

  if (resolvedType === 'VOICE_NOTE') {
    // Not z.coerce.number() — Number(...) is what the original check used,
    // and coercion edge cases differ, so this preserves exact behavior.
    const duration = Number(data.durationSeconds);
    if (!Number.isInteger(duration) || duration <= 0) {
      throw new HttpError(400, 'durationSeconds must be a positive integer for a voice note');
    }
  }

  if (req.file) {
    if (resolvedType === 'IMAGE' && !req.file.mimetype.startsWith('image/')) {
      throw new HttpError(400, 'File must be an image for type IMAGE');
    }
    if (resolvedType === 'VIDEO' && !req.file.mimetype.startsWith('video/')) {
      throw new HttpError(400, 'File must be a video for type VIDEO');
    }
    if (resolvedType === 'VOICE_NOTE' && !req.file.mimetype.startsWith('audio/')) {
      throw new HttpError(400, 'File must be audio for type VOICE_NOTE');
    }
  }

  // Write the resolved, validated values back so the controller/service
  // don't need to re-derive the type default or re-trim content.
  req.body.type = resolvedType;
  req.body.content = trimmedContent;
}

export const reactToMessageSchema = z
  .object({ emoji: optionalString() })
  .superRefine((data, ctx) => {
    if (!data.emoji || !data.emoji.trim()) {
      ctx.addIssue('emoji is required');
      return;
    }
    if (data.emoji.length > MAX_EMOJI_LENGTH) {
      ctx.addIssue('emoji is too long');
    }
  });
