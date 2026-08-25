import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { assertMembership } from './conversation.js';
import { getIo } from '../realtime/io.js';
import { conversationRoom } from '../realtime/rooms.js';

export async function markMessagesRead(
  conversationId: string,
  userId: string,
  upToMessageId: string,
): Promise<{ count: number }> {
  await assertMembership(conversationId, userId);

  const target = await prisma.message.findUnique({
    where: { id: upToMessageId, conversationId },
    select: { createdAt: true },
  });
  if (!target) throw new HttpError(404, 'Message not found');

  const rows = await prisma.message.findMany({
    where: { conversationId, createdAt: { lte: target.createdAt }, senderId: { not: userId }, deletedAt: null },
    select: { id: true },
  });

  const [result] = await prisma.$transaction([
    prisma.messageRead.createMany({
      data: rows.map((r) => ({ messageId: r.id, userId })),
      skipDuplicates: true,
    }),
    prisma.conversationMember.updateMany({
      where: { conversationId, userId },
      data: { lastReadAt: target.createdAt },
    }),
  ]);

  getIo().to(conversationRoom(conversationId)).emit('message:read', {
    conversationId,
    userId,
    upToMessageId,
    readAt: new Date(),
  });

  return { count: result.count };
}
