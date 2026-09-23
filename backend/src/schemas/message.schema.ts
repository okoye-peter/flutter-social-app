import type { Request } from 'express';
import { z } from 'zod';
import { HttpError } from '../lib/http-error.js';
import { MessageType } from '../../generated/prisma/index.js';
import { MAX_CONTENT_LENGTH } from '../services/message.js';
import { MAX_EMOJI_LENGTH } from '../services/reaction.js';
import { optionalString } from './shared.js';

// SYSTEM is deliberately excluded — those are only ever created internally
// (see conversation.ts's postSystemMessage), never client-submitted.
const VALID_TYPES = Object.values(MessageType).filter((type) => type !== 'SYSTEM');
const CHAT_ATTACHMENT_TYPES = ['IMAGE', 'VIDEO', 'VOICE_NOTE'] as const;

export const uploadAuthSchema = z.object({
  type: z.enum(CHAT_ATTACHMENT_TYPES),
});

const IMAGE_FORMATS = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'gif'];
const VOICE_FORMATS = ['m4a', 'aac', 'mp3', 'wav', 'ogg'];

// Attachments now upload directly to Cloudinary from the client (see
// services/cloudinary.ts's createChatAttachmentUploadAuth) — the bytes
// never touch this server, so this is a plain JSON body, not multipart.
const MAX_CHAT_ATTACHMENT_SIZE_MB = Number(process.env.MAX_CHAT_ATTACHMENT_SIZE_MB ?? 9);
const MAX_CHAT_ATTACHMENT_SIZE_BYTES = MAX_CHAT_ATTACHMENT_SIZE_MB * 1024 * 1024;

export const sendMessageSchema = z.object({
  type: optionalString(),
  content: optionalString(),
  replyToId: optionalString(),
  mentionedUserIds: z.array(z.string()).optional().nullable().transform((v) => v ?? undefined),
  durationSeconds: z.number().int().positive().optional().nullable().transform((v) => v ?? undefined),
  fileUrl: z.string().url().optional().nullable().transform((v) => v ?? undefined),
  fileName: optionalString(),
  fileSize: z.number().int().positive().optional().nullable().transform((v) => v ?? undefined),
  fileResourceType: z.enum(['image', 'video']).optional().nullable().transform((v) => v ?? undefined),
  fileFormat: optionalString(),
});

export type SendMessageData = z.infer<typeof sendMessageSchema>;

// Successor to the old checkSendMessageFile: the file already lives on
// Cloudinary by the time this runs (see the upload-auth flow), so these
// checks validate the client-supplied fileUrl/metadata instead of req.file.
export function checkSendMessageAttachment(_req: Request, data: SendMessageData) {
  const resolvedType = (data.type ?? (data.fileUrl ? 'FILE' : 'TEXT')).toUpperCase();
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
  if (resolvedType !== 'TEXT' && !data.fileUrl) {
    throw new HttpError(400, `A fileUrl is required for type ${resolvedType}`);
  }

  if (resolvedType === 'VOICE_NOTE' && (!data.durationSeconds || data.durationSeconds <= 0)) {
    throw new HttpError(400, 'durationSeconds must be a positive integer for a voice note');
  }

  if (data.fileUrl) {
    // The backend used to upload the file itself, so this URL was always
    // ours by construction. Now the client hands us an arbitrary string —
    // this is a new, real check, not a formality.
    if (!data.fileUrl.startsWith(`https://res.cloudinary.com/${process.env.CLOUDINARY_CLOUD_NAME}/`)) {
      throw new HttpError(400, 'fileUrl must be a Cloudinary URL for this account');
    }

    if (data.fileSize && data.fileSize > MAX_CHAT_ATTACHMENT_SIZE_BYTES) {
      throw new HttpError(400, `Attachment is too large (max ${MAX_CHAT_ATTACHMENT_SIZE_MB}MB)`);
    }

    // Cross-check replacing multer's old mimetype-prefix check. Not a
    // weaker trust level than before: multer's fileFilter only ever
    // trusted the client's declared Content-Type header too, never
    // inspected bytes. fileResourceType/fileFormat here are themselves
    // Cloudinary's own post-upload response fields — Cloudinary determined
    // them by inspecting the actual bytes it received — just relayed by
    // the client rather than fetched by us from Cloudinary's Admin API.
    if (data.fileResourceType && data.fileFormat) {
      if (resolvedType === 'IMAGE' && (data.fileResourceType !== 'image' || !IMAGE_FORMATS.includes(data.fileFormat))) {
        throw new HttpError(400, 'File must be an image for type IMAGE');
      }
      if (resolvedType === 'VIDEO' && (data.fileResourceType !== 'video' || VOICE_FORMATS.includes(data.fileFormat))) {
        throw new HttpError(400, 'File must be a video for type VIDEO');
      }
      if (resolvedType === 'VOICE_NOTE' && (data.fileResourceType !== 'video' || !VOICE_FORMATS.includes(data.fileFormat))) {
        throw new HttpError(400, 'File must be audio for type VOICE_NOTE');
      }
    }
  }

  // Write the resolved, validated values back so the controller/service
  // don't need to re-derive the type default or re-trim content.
  data.type = resolvedType;
  data.content = trimmedContent;
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
