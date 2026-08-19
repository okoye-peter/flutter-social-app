import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { isUniqueConstraintError, isRecordNotFoundError } from '../lib/prisma-errors.js';
import { assertMembership } from './conversation.js';
import { toSafeUser } from './auth.js';
import { getIo } from '../realtime/io.js';
import { conversationRoom } from '../realtime/rooms.js';
import type { PinnedMessage } from '../../generated/prisma/index.js';

async function assertCanPin(conversationId: string, userId: string): Promise<void> {
  const member = await assertMembership(conversationId, userId);
  const conversation = await prisma.conversation.findUniqueOrThrow({
    where: { id: conversationId },
    select: { type: true },
  });
  if (conversation.type === 'GROUP' && member.role !== 'OWNER' && member.role !== 'ADMIN') {
    throw new HttpError(403, 'Only group admins can pin messages');
  }
}

export async function pinMessage(messageId: string, userId: string): Promise<PinnedMessage> {
  const message = await prisma.message.findUnique({ where: { id: messageId, deletedAt: null } });
  if (!message) throw new HttpError(404, 'Message not found');
  await assertCanPin(message.conversationId, userId);

  try {
    const pin = await prisma.pinnedMessage.create({
      data: { conversationId: message.conversationId, messageId, pinnedById: userId },
    });
    getIo().to(conversationRoom(message.conversationId)).emit('message:pinned', {
      conversationId: message.conversationId,
      messageId,
    });
    return pin;
  } catch (e) {
    if (isUniqueConstraintError(e)) {
      return prisma.pinnedMessage.findUniqueOrThrow({
        where: { conversationId_messageId: { conversationId: message.conversationId, messageId } },
      }); // already pinned — idempotent no-op
    }
    throw e;
  }
}

export async function unpinMessage(messageId: string, userId: string): Promise<void> {
  const message = await prisma.message.findUnique({ where: { id: messageId }, select: { conversationId: true } });
  if (!message) return; // already gone — idempotent no-op
  await assertCanPin(message.conversationId, userId);

  try {
    await prisma.pinnedMessage.delete({
      where: { conversationId_messageId: { conversationId: message.conversationId, messageId } },
    });
  } catch (e) {
    if (isRecordNotFoundError(e)) return;
    throw e;
  }

  getIo().to(conversationRoom(message.conversationId)).emit('message:unpinned', {
    conversationId: message.conversationId,
    messageId,
  });
}

export async function listPinned(conversationId: string, viewerId: string) {
  await assertMembership(conversationId, viewerId);

  const pins = await prisma.pinnedMessage.findMany({
    where: { conversationId },
    orderBy: { pinnedAt: 'desc' },
    include: { message: true, pinnedBy: true },
  });

  return {
    pins: pins.map((p) => {
      const { pinnedBy, ...rest } = p;
      return { ...rest, pinnedBy: pinnedBy ? toSafeUser(pinnedBy) : null };
    }),
  };
}
