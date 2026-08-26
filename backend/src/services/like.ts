import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { isUniqueConstraintError, isRecordNotFoundError } from '../lib/prisma-errors.js';
import { assertNotBlocked } from './block.js';
import { createNotification } from './notifications.js';

export async function likePost(postId: string, userId: string): Promise<{ likesCount: number }> {
  const post = await prisma.post.findUnique({ where: { id: postId }, select: { userId: true } });
  if (!post) throw new HttpError(404, 'Post not found');
  await assertNotBlocked(post.userId, userId);

  try {
    const updated = await prisma.$transaction(async (tx) => {
      await tx.postLike.create({ data: { postId, userId } });
      return tx.post.update({ where: { id: postId }, data: { likesCount: { increment: 1 } } });
    });
    await createNotification({ userId: post.userId, actorId: userId, type: 'POST_LIKE', postId });
    return { likesCount: updated.likesCount };
  } catch (e) {
    if (isUniqueConstraintError(e)) {
      const p = await prisma.post.findUniqueOrThrow({ where: { id: postId }, select: { likesCount: true } });
      return { likesCount: p.likesCount }; // already liked — idempotent no-op
    }
    throw e;
  }
}

export async function unlikePost(postId: string, userId: string): Promise<{ likesCount: number }> {
  try {
    const updated = await prisma.$transaction(async (tx) => {
      await tx.postLike.delete({ where: { postId_userId: { postId, userId } } });
      return tx.post.update({ where: { id: postId }, data: { likesCount: { decrement: 1 } } });
    });
    return { likesCount: updated.likesCount };
  } catch (e) {
    if (isRecordNotFoundError(e)) {
      const p = await prisma.post.findUnique({ where: { id: postId }, select: { likesCount: true } });
      if (!p) throw new HttpError(404, 'Post not found');
      return { likesCount: p.likesCount }; // not liked — idempotent no-op
    }
    throw e;
  }
}

export async function likeComment(commentId: string, userId: string): Promise<{ likesCount: number }> {
  const comment = await prisma.comment.findUnique({ where: { id: commentId }, select: { userId: true, deletedAt: true } });
  if (!comment || comment.deletedAt) throw new HttpError(404, 'Comment not found');
  await assertNotBlocked(comment.userId, userId);

  try {
    const updated = await prisma.$transaction(async (tx) => {
      await tx.commentLike.create({ data: { commentId, userId } });
      return tx.comment.update({ where: { id: commentId }, data: { likesCount: { increment: 1 } } });
    });
    await createNotification({ userId: comment.userId, actorId: userId, type: 'COMMENT_LIKE', commentId });
    return { likesCount: updated.likesCount };
  } catch (e) {
    if (isUniqueConstraintError(e)) {
      const c = await prisma.comment.findUniqueOrThrow({ where: { id: commentId }, select: { likesCount: true } });
      return { likesCount: c.likesCount }; // already liked — idempotent no-op
    }
    throw e;
  }
}

export async function unlikeComment(commentId: string, userId: string): Promise<{ likesCount: number }> {
  try {
    const updated = await prisma.$transaction(async (tx) => {
      await tx.commentLike.delete({ where: { commentId_userId: { commentId, userId } } });
      return tx.comment.update({ where: { id: commentId }, data: { likesCount: { decrement: 1 } } });
    });
    return { likesCount: updated.likesCount };
  } catch (e) {
    if (isRecordNotFoundError(e)) {
      const c = await prisma.comment.findUnique({ where: { id: commentId }, select: { likesCount: true } });
      if (!c) throw new HttpError(404, 'Comment not found');
      return { likesCount: c.likesCount }; // not liked — idempotent no-op
    }
    throw e;
  }
}
