import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import type { Report, ReportReason } from '../../generated/prisma/index.js';

const VALID_REASONS: ReportReason[] = ['SPAM', 'HARASSMENT', 'HATE_SPEECH', 'NUDITY', 'VIOLENCE', 'MISINFORMATION', 'OTHER'];

export interface CreateReportInput {
  reporterId: string;
  reason?: string;
  details?: string;
  postId?: string;
  commentId?: string;
  reportedUserId?: string;
}

export async function createReport(input: CreateReportInput): Promise<Report> {
  const { reporterId, reason, details, postId, commentId, reportedUserId } = input;

  if (!reason || !VALID_REASONS.includes(reason as ReportReason)) {
    throw new HttpError(400, `reason must be one of: ${VALID_REASONS.join(', ')}`);
  }

  const targets = [postId, commentId, reportedUserId].filter((t) => t !== undefined);
  if (targets.length !== 1) {
    throw new HttpError(400, 'Provide exactly one of postId, commentId, or reportedUserId');
  }

  if (reportedUserId === reporterId) {
    throw new HttpError(400, 'You cannot report yourself');
  }

  if (postId) {
    const post = await prisma.post.findUnique({ where: { id: postId }, select: { id: true } });
    if (!post) throw new HttpError(404, 'Post not found');
  } else if (commentId) {
    const comment = await prisma.comment.findUnique({ where: { id: commentId }, select: { id: true } });
    if (!comment) throw new HttpError(404, 'Comment not found');
  } else if (reportedUserId) {
    const user = await prisma.user.findUnique({ where: { id: reportedUserId }, select: { id: true } });
    if (!user) throw new HttpError(404, 'User not found');
  }

  return prisma.report.create({
    data: {
      reporterId,
      reason: reason as ReportReason,
      details: details?.trim() || undefined,
      postId,
      commentId,
      reportedUserId,
    },
  });
}
