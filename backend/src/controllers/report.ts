import type { Request, Response } from 'express';
import * as reportService from '../services/report.js';

export async function createReport(req: Request, res: Response) {
  const { reason, details, postId, commentId, reportedUserId } = req.body as {
    reason?: string;
    details?: string;
    postId?: string;
    commentId?: string;
    reportedUserId?: string;
  };
  const report = await reportService.createReport({
    reporterId: req.userId!,
    reason,
    details,
    postId,
    commentId,
    reportedUserId,
  });
  res.status(201).json({ report });
}
