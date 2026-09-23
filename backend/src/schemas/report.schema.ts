import { z } from 'zod';
import { optionalString } from './shared.js';
import { ReportReason } from '../../generated/prisma/index.js';

const REASONS = Object.values(ReportReason);

export const createReportSchema = z
  .object({
    reason: optionalString(),
    details: optionalString(),
    postId: optionalString(),
    commentId: optionalString(),
    reportedUserId: optionalString(),
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
