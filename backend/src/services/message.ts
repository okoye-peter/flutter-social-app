import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { isRecordNotFoundError, isUniqueConstraintError } from '../lib/prisma-errors.js';
import { decodeCursor, buildCursorWhere, toPage, parseLimit, type CursorPage } from '../lib/pagination.js';
import { assertMembership, assertCanPostToConversation } from './conversation.js';
import { createChatAttachmentUploadAuth, type ChatAttachmentType, type SignedUploadAuth } from './cloudinary.js';
import { toSafeUser, type SafeUser } from './auth.js';
import { createNotification } from './notifications.js';
import { getIo } from '../realtime/io.js';
import { conversationRoom } from '../realtime/rooms.js';
import type { Message, MessageType } from '../../generated/prisma/index.js';

export const MAX_CONTENT_LENGTH = 4000;

export interface SendMessageInput {
  conversationId: string;
  senderId: string;
  type: string;
  content?: string;
  fileUrl?: string;
  fileName?: string;
  fileSize?: number;
  replyToId?: string;
  mentionedUserIds?: string[];
  durationSeconds?: number;
}

export async function getUploadAuth(
  conversationId: string,
  userId: string,
  type: ChatAttachmentType,
): Promise<SignedUploadAuth> {
  await assertCanPostToConversation(conversationId, userId);
  return createChatAttachmentUploadAuth(conversationId, type);
}

// Just enough of the replied-to message for the client's quoted preview —
// included on sends (response + `message:new`) and on listMessages, so a
// reply renders correctly even when its parent is outside the loaded page.
const REPLY_TO_SELECT = {
  id: true,
  type: true,
  content: true,
  deletedAt: true,
  sender: { select: { id: true, name: true } },
} as const;

export async function sendMessage(input: SendMessageInput): Promise<Message> {
  const { conversationId, senderId, content, fileUrl, fileName, fileSize, replyToId, mentionedUserIds, durationSeconds } = input;
  await assertCanPostToConversation(conversationId, senderId);

  // type, content, and durationSeconds are already resolved/validated by
  // checkSendMessageAttachment (content is already trimmed) — this only
  // derives what actually needs to be written. The attachment, if any, is
  // already on Cloudinary by this point (see getUploadAuth) — this is now
  // a pure DB write with no external I/O.
  const type = input.type as MessageType;
  const trimmedContent = content;
  const duration = type === 'VOICE_NOTE' ? durationSeconds : undefined;

  if (replyToId) {
    const parent = await prisma.message.findUnique({
      where: { id: replyToId, conversationId, deletedAt: null },
      select: { id: true },
    });
    if (!parent) throw new HttpError(404, 'Message being replied to was not found');
  }

  const { msg: message, conversationType } = await prisma.$transaction(async (tx) => {
    const msg = await tx.message.create({
      data: {
        conversationId,
        senderId,
        type,
        content: trimmedContent,
        fileUrl,
        fileName,
        fileSize,
        duration,
        replyToId,
      },
      include: { replyTo: { select: REPLY_TO_SELECT } },
    });
    const conversation = await tx.conversation.update({
      where: { id: conversationId },
      data: { lastMessageAt: msg.createdAt },
      select: { type: true },
    });
    return { msg, conversationType: conversation.type };
  });

  const activeMembers = await prisma.conversationMember.findMany({
    where: { conversationId, leftAt: null },
    select: { userId: true },
  });
  const recipientIds = activeMembers.map((m) => m.userId).filter((id) => id !== senderId);

  const uniqueMentionIds = [...new Set(mentionedUserIds ?? [])].filter(
    (id) => id !== senderId && recipientIds.includes(id),
  );
  for (const userId of uniqueMentionIds) {
    try {
      await prisma.messageMention.create({ data: { messageId: message.id, userId } });
    } catch (e) {
      if (!isUniqueConstraintError(e)) throw e;
    }
  }

  // conversationType lets clients route the event without a lookup — e.g.
  // the direct-chat inbox ignores GROUP messages instead of refetching.
  getIo().to(conversationRoom(conversationId)).emit('message:new', { message, conversationType });

  await Promise.all(
    recipientIds.map((userId) =>
      createNotification({
        userId,
        actorId: senderId,
        type: uniqueMentionIds.includes(userId) ? 'MENTION' : 'MESSAGE',
        conversationId,
        messageId: message.id,
      }),
    ),
  );

  return message;
}

const MESSAGE_VIEWER_STATE_INCLUDE = (viewerId: string) => ({
  sender: true,
  // Every reaction (one per user), not just the viewer's — the client shows
  // per-emoji counts and applies live `message:reaction` updates per user.
  reactions: { select: { emoji: true, userId: true } },
  reads: { where: { userId: viewerId }, select: { id: true } },
  replyTo: { select: REPLY_TO_SELECT },
});

type MessageWithRawViewerState = Message & {
  sender: import('../../generated/prisma/index.js').User | null;
  reactions: { emoji: string; userId: string }[];
  reads: { id: string }[];
};

export type MessageWithViewerState = Omit<Message, 'senderId'> & {
  sender: SafeUser | null;
  reactions: { emoji: string; userId: string }[];
  myReaction: string | null;
  readByMe: boolean;
};

function withViewerState(message: MessageWithRawViewerState, viewerId: string): MessageWithViewerState {
  const { sender, reactions, reads, senderId: _senderId, ...rest } = message;
  return {
    ...rest,
    sender: sender ? toSafeUser(sender) : null,
    reactions,
    myReaction: reactions.find((r) => r.userId === viewerId)?.emoji ?? null,
    readByMe: reads.length > 0,
  };
}

export async function listMessages(
  conversationId: string,
  viewerId: string,
  query: { cursor?: string; limit?: string },
): Promise<CursorPage<MessageWithViewerState>> {
  await assertMembership(conversationId, viewerId);

  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const rows = await prisma.message.findMany({
    where: { conversationId, deletedAt: null, ...buildCursorWhere(cursor) },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    include: MESSAGE_VIEWER_STATE_INCLUDE(viewerId),
  });

  const page = toPage(rows, limit);
  return { items: page.items.map((m) => withViewerState(m, viewerId)), nextCursor: page.nextCursor };
}

export async function deleteMessage(messageId: string, userId: string): Promise<void> {
  const message = await prisma.message.findUnique({ where: { id: messageId, deletedAt: null } });
  if (!message) return; // already gone — idempotent no-op
  if (message.senderId !== userId) throw new HttpError(403, 'Only the sender can delete this message');

  try {
    await prisma.message.update({ where: { id: messageId }, data: { deletedAt: new Date() } });
  } catch (e) {
    if (isRecordNotFoundError(e)) return;
    throw e;
  }

  getIo().to(conversationRoom(message.conversationId)).emit('message:deleted', {
    messageId,
    conversationId: message.conversationId,
  });
}
