import { Router } from 'express';
import * as commentController from '../controllers/comment.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { updateCommentSchema } from '../schemas/comment.schema.js';

export const commentsRouter = Router();

commentsRouter.get('/:id', requireAuth, commentController.getComment);
commentsRouter.put('/:id', requireAuth, validate(updateCommentSchema), commentController.updateComment);
commentsRouter.delete('/:id', requireAuth, commentController.deleteComment);

commentsRouter.get('/:id/replies', requireAuth, commentController.listReplies);

commentsRouter.post('/:id/likes', requireAuth, commentController.likeComment);
commentsRouter.delete('/:id/likes', requireAuth, commentController.unlikeComment);
