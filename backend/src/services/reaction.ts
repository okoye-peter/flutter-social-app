import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { isRecordNotFoundError } from '../lib/prisma-errors.js';
import { assertMembership } from './conversation.js';
import { getIo } from '../realtime/io.js';
import { conversationRoom } from '../realtime/rooms.js';
import type { MessageReaction } from '../../generated/prisma/index.js';

const MAX_EMOJI_LENGTH = 32; // generous enough for multi-codepoint ZWJ emoji sequences

async function getMessageOrThrow(messageId: string) {
  const message = await prisma.message.findUnique({ where: { id: messageId, deletedAt: null } });
  if (!message) throw new HttpError(404, 'Message not found');
  return message;
}

export async function reactToMessage(messageId: string, userId: string, emoji: string | undefined): Promise<MessageReaction> {
  if (!emoji || !emoji.trim()) throw new HttpError(400, 'emoji is required');
  if (emoji.length > MAX_EMOJI_LENGTH) throw new HttpError(400, 'emoji is too long');

  const message = await getMessageOrThrow(messageId);
  await assertMembership(message.conversationId, userId);

  const reaction = await prisma.messageReaction.upsert({
    where: { messageId_userId: { messageId, userId } },
    create: { messageId, userId, emoji },
    update: { emoji },
  });

  getIo().to(conversationRoom(message.conversationId)).emit('message:reaction', { messageId, userId, emoji });
  return reaction;
}

export async function unreactToMessage(messageId: string, userId: string): Promise<void> {
  const message = await prisma.message.findUnique({ where: { id: messageId }, select: { conversationId: true } });
  if (!message) return; // already gone — idempotent no-op

  try {
    await prisma.messageReaction.delete({ where: { messageId_userId: { messageId, userId } } });
  } catch (e) {
    if (isRecordNotFoundError(e)) return;
    throw e;
  }

  getIo().to(conversationRoom(message.conversationId)).emit('message:reaction-removed', { messageId, userId });
}
