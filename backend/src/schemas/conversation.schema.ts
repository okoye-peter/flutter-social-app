import { z } from 'zod';
import { optionalJsonStringArray, optionalString } from './shared.js';

function checkVisibility(visibility: string | undefined, ctx: z.RefinementCtx) {
  if (visibility !== undefined && visibility !== 'PRIVATE' && visibility !== 'PUBLIC') {
    ctx.addIssue("visibility must be 'PRIVATE' or 'PUBLIC'");
  }
}

export const createConversationSchema = z
  .object({
    type: optionalString(),
    participantId: optionalString(),
    name: optionalString(),
    visibility: optionalString(),
    memberIds: optionalJsonStringArray('memberIds'),
  })
  .superRefine((data, ctx) => {
    const type = data.type ?? 'DIRECT';

    if (type === 'DIRECT') {
      if (!data.participantId) {
        ctx.addIssue('participantId is required for a direct conversation');
      }
      return;
    }

    if (type !== 'GROUP') {
      ctx.addIssue("type must be 'DIRECT' or 'GROUP'");
      return;
    }
    if (!data.name?.trim()) {
      ctx.addIssue('name is required for a group conversation');
      return;
    }
    checkVisibility(data.visibility, ctx);
  });

export const updateConversationSchema = z
  .object({ name: optionalString(), visibility: optionalString() })
  .superRefine((data, ctx) => {
    if (data.name !== undefined && !data.name.trim()) {
      ctx.addIssue('name cannot be empty');
      return;
    }
    checkVisibility(data.visibility, ctx);
  });

export const addMembersSchema = z
  .object({ memberIds: z.array(z.string()).optional().nullable() })
  .superRefine((data, ctx) => {
    if (!data.memberIds || data.memberIds.length === 0) {
      ctx.addIssue('memberIds is required');
    }
  });

export const respondJoinRequestSchema = z.object({
  accept: z.boolean(),
});

export const markReadSchema = z
  .object({ upToMessageId: optionalString() })
  .superRefine((data, ctx) => {
    if (!data.upToMessageId) {
      ctx.addIssue('upToMessageId is required');
    }
  });
