import { z } from 'zod';
import { ReportReason } from '../../generated/prisma/index.js';

const REASONS = Object.values(ReportReason);

export const createReportSchema = z
  .object({
    reason: z.string().optional(),
    details: z.string().optional(),
    postId: z.string().optional(),
    commentId: z.string().optional(),
    reportedUserId: z.string().optional(),
  })
  .superRefine((data, ctx) => {
    if (!data.reason || !REASONS.includes(data.reason as (typeof REASONS)[number])) {
      ctx.addIssue(`reason must be one of: ${REASONS.join(', ')}`);
      return;
    }
    const targets = [data.postId, data.commentId, data.reportedUserId].filter((t) => t !== undefined);
    if (targets.length !== 1) {
      ctx.addIssue('Provide exactly one of postId, commentId, or reportedUserId');
    }
  });
