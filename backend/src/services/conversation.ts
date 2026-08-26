import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { decodeCursor, encodeCursor, parseLimit } from '../lib/pagination.js';
import { toSafeUser, type SafeUser } from './auth.js';
import { uploadImage } from './cloudinary.js';
import { joinUserToConversation, leaveUserFromConversation } from '../realtime/rooms.js';
import { getIo } from '../realtime/io.js';
import { conversationRoom } from '../realtime/rooms.js';
import type {
  Conversation,
  ConversationMember,
  MemberRole,
  GroupVisibility,
} from '../../generated/prisma/index.js';

const MAX_GROUP_MEMBERS = 200;

export interface ConversationDTO extends Conversation {
  members: (Omit<ConversationMember, 'user'> & { user: SafeUser })[];
  createdBy: SafeUser | null;
}

async function toConversationDTO(conversationId: string): Promise<ConversationDTO> {
  const conversation = await prisma.conversation.findUniqueOrThrow({
    where: { id: conversationId },
    include: {
      createdBy: true,
      members: { where: { leftAt: null }, include: { user: true } },
    },
  });
  const { createdBy, members, ...rest } = conversation;
  return {
    ...rest,
    createdBy: createdBy ? toSafeUser(createdBy) : null,
    members: members.map((m) => {
      const { user, ...memberRest } = m;
      return { ...memberRest, user: toSafeUser(user) };
    }),
  } as ConversationDTO;
}

export async function assertMembership(conversationId: string, userId: string): Promise<ConversationMember> {
  const member = await prisma.conversationMember.findFirst({
    where: { conversationId, userId, leftAt: null },
  });
  if (!member) {
    // Same conversation-not-found 404 whether it doesn't exist or the caller
    // just isn't a member of it — don't leak which case it is.
    throw new HttpError(404, 'Conversation not found');
  }
  return member;
}

export async function assertRole(
  conversationId: string,
  userId: string,
  roles: MemberRole[],
): Promise<ConversationMember> {
  const member = await assertMembership(conversationId, userId);
  if (!roles.includes(member.role)) {
    throw new HttpError(403, 'You do not have permission to do this');
  }
  return member;
}

async function assertGroup(conversationId: string): Promise<Conversation> {
  const conversation = await prisma.conversation.findUnique({ where: { id: conversationId } });
  if (!conversation) throw new HttpError(404, 'Conversation not found');
  if (conversation.type !== 'GROUP') {
    throw new HttpError(400, 'This operation is only available for group conversations');
  }
  return conversation;
}

// Minimal, self-contained SYSTEM-message writer for membership events. Not
// routed through message.ts's sendMessage (which requires assertMembership
// on the actor and accepts uploads/mentions) to avoid a circular import
// between conversation.ts and message.ts — this only needs the bare
// "persist + bump lastMessageAt + emit" mechanics.
async function postSystemMessage(conversationId: string, content: string): Promise<void> {
  const message = await prisma.$transaction(async (tx) => {
    const msg = await tx.message.create({ data: { conversationId, type: 'SYSTEM', content } });
    await tx.conversation.update({ where: { id: conversationId }, data: { lastMessageAt: msg.createdAt } });
    return msg;
  });
  getIo().to(conversationRoom(conversationId)).emit('message:new', { message });
}

export interface CreateConversationInput {
  creatorId: string;
  type: string;
  participantId?: string; // DIRECT
  name?: string; // GROUP
  visibility?: string; // GROUP
  memberIds?: string[]; // GROUP, initial members besides creator
  imageFile?: { buffer: Buffer };
}

export async function createConversation(input: CreateConversationInput): Promise<ConversationDTO> {
  const { creatorId, type, participantId, name, visibility, memberIds, imageFile } = input;

  if (type === 'DIRECT') {
    // participantId's presence for DIRECT is enforced by createConversationSchema.
    const targetId = participantId!;
    if (targetId === creatorId) throw new HttpError(400, 'Cannot start a conversation with yourself');

    const existing = await prisma.conversation.findFirst({
      where: {
        type: 'DIRECT',
        members: {
          some: { userId: creatorId, leftAt: null },
          every: { userId: { in: [creatorId, targetId] } },
        },
      },
    });
    if (existing) return toConversationDTO(existing.id);

    const target = await prisma.user.findUnique({ where: { id: targetId }, select: { id: true } });
    if (!target) throw new HttpError(404, 'User not found');

    const conversation = await prisma.conversation.create({
      data: {
        type: 'DIRECT',
        createdById: creatorId,
        members: {
          create: [
            { userId: creatorId, role: 'MEMBER' },
            { userId: targetId, role: 'MEMBER' },
          ],
        },
      },
    });
    joinUserToConversation(creatorId, conversation.id);
    joinUserToConversation(targetId, conversation.id);
    return toConversationDTO(conversation.id);
  }

  // name's presence for GROUP is enforced by createConversationSchema.
  const groupName = name!;
  const groupVisibility: GroupVisibility = (visibility ?? 'PRIVATE') as GroupVisibility;

  const uniqueMemberIds = [...new Set(memberIds ?? [])].filter((id) => id !== creatorId);
  if (uniqueMemberIds.length + 1 > MAX_GROUP_MEMBERS) {
    throw new HttpError(400, `A group can have at most ${MAX_GROUP_MEMBERS} members`);
  }
  const existingUsers = await prisma.user.findMany({
    where: { id: { in: uniqueMemberIds } },
    select: { id: true },
  });
  const validMemberIds = existingUsers.map((u) => u.id);

  const image = imageFile ? await uploadImage(imageFile.buffer, 'conversation-images') : undefined;

  const conversation = await prisma.conversation.create({
    data: {
      type: 'GROUP',
      name: groupName.trim(),
      image,
      visibility: groupVisibility,
      createdById: creatorId,
      members: {
        create: [
          { userId: creatorId, role: 'OWNER' },
          ...validMemberIds.map((userId) => ({ userId, role: 'MEMBER' as MemberRole })),
        ],
      },
    },
  });

  joinUserToConversation(creatorId, conversation.id);
  for (const userId of validMemberIds) joinUserToConversation(userId, conversation.id);

  return toConversationDTO(conversation.id);
}

export async function getConversation(conversationId: string, viewerId: string): Promise<ConversationDTO> {
  await assertMembership(conversationId, viewerId);
  return toConversationDTO(conversationId);
}

export async function listMyConversations(
  viewerId: string,
  query: { cursor?: string; limit?: string },
) {
  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const memberships = await prisma.conversationMember.findMany({
    where: { userId: viewerId, leftAt: null },
    select: { conversationId: true, lastReadAt: true },
  });
  const lastReadByConversation = new Map(memberships.map((m) => [m.conversationId, m.lastReadAt]));
  const conversationIds = memberships.map((m) => m.conversationId);

  const rows = await prisma.conversation.findMany({
    where: {
      id: { in: conversationIds },
      ...(cursor
        ? {
            OR: [
              { lastMessageAt: { lt: cursor.createdAt } },
              { lastMessageAt: cursor.createdAt, id: { lt: cursor.id } },
            ],
          }
        : {}),
    },
    orderBy: [{ lastMessageAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    include: {
      members: { where: { leftAt: null }, include: { user: true } },
      messages: { orderBy: { createdAt: 'desc' }, take: 1 },
    },
  });

  const hasMore = rows.length > limit;
  const page = hasMore ? rows.slice(0, limit) : rows;
  const last = page.at(-1);
  const nextCursor = hasMore && last ? encodeCursor(last.lastMessageAt ?? last.createdAt, last.id) : null;

  const items = await Promise.all(
    page.map(async (conversation) => {
      const lastReadAt = lastReadByConversation.get(conversation.id) ?? new Date(0);
      const unreadCount = await prisma.message.count({
        where: {
          conversationId: conversation.id,
          createdAt: { gt: lastReadAt },
          senderId: { not: viewerId },
          deletedAt: null,
        },
      });
      const { members, messages, ...rest } = conversation;
      return {
        ...rest,
        members: members.map((m) => {
          const { user, ...memberRest } = m;
          return { ...memberRest, user: toSafeUser(user) };
        }),
        lastMessage: messages[0] ?? null,
        unreadCount,
      };
    }),
  );

  return { items, nextCursor };
}

export interface UpdateConversationInput {
  name?: string;
  visibility?: string;
  imageFile?: { buffer: Buffer };
}

export async function updateConversation(
  conversationId: string,
  userId: string,
  input: UpdateConversationInput,
): Promise<ConversationDTO> {
  await assertGroup(conversationId);
  await assertRole(conversationId, userId, ['OWNER', 'ADMIN']);

  const { name, visibility, imageFile } = input;
  const image = imageFile ? await uploadImage(imageFile.buffer, 'conversation-images') : undefined;

  await prisma.conversation.update({
    where: { id: conversationId },
    data: {
      ...(name !== undefined ? { name: name.trim() } : {}),
      ...(visibility !== undefined ? { visibility: visibility as GroupVisibility } : {}),
      ...(image !== undefined ? { image } : {}),
    },
  });

  return toConversationDTO(conversationId);
}

export async function addMembers(conversationId: string, userId: string, memberIds: string[]): Promise<ConversationDTO> {
  await assertGroup(conversationId);
  await assertRole(conversationId, userId, ['OWNER', 'ADMIN']);

  const currentCount = await prisma.conversationMember.count({ where: { conversationId, leftAt: null } });
  const uniqueIds = [...new Set(memberIds)];
  if (currentCount + uniqueIds.length > MAX_GROUP_MEMBERS) {
    throw new HttpError(400, `A group can have at most ${MAX_GROUP_MEMBERS} members`);
  }

  const existingUsers = await prisma.user.findMany({ where: { id: { in: uniqueIds } }, select: { id: true, name: true } });

  for (const user of existingUsers) {
    const existingMember = await prisma.conversationMember.findUnique({
      where: { conversationId_userId: { conversationId, userId: user.id } },
    });
    if (existingMember) {
      if (existingMember.leftAt !== null) {
        await prisma.conversationMember.update({
          where: { id: existingMember.id },
          data: { leftAt: null, role: 'MEMBER', joinedAt: new Date() },
        });
        joinUserToConversation(user.id, conversationId);
        await postSystemMessage(conversationId, `${user.name} joined the group`);
      }
      continue; // already an active member — no-op
    }
    await prisma.conversationMember.create({ data: { conversationId, userId: user.id, role: 'MEMBER' } });
    joinUserToConversation(user.id, conversationId);
    await postSystemMessage(conversationId, `${user.name} was added to the group`);
  }

  getIo().to(conversationRoom(conversationId)).emit('conversation:member-added', { conversationId, memberIds: existingUsers.map((u) => u.id) });

  return toConversationDTO(conversationId);
}

// Shared by removeMember (admin removing someone else) and leaveConversation
// (self-removal) — both are "mark this membership as left" plus ownership
// succession if the departing member was the OWNER.
async function departMember(conversationId: string, targetUserId: string): Promise<void> {
  const target = await prisma.conversationMember.findFirst({
    where: { conversationId, userId: targetUserId, leftAt: null },
    include: { user: { select: { name: true } } },
  });
  if (!target) return; // already gone — idempotent no-op

  await prisma.conversationMember.update({ where: { id: target.id }, data: { leftAt: new Date() } });
  leaveUserFromConversation(targetUserId, conversationId);

  if (target.role === 'OWNER') {
    const successor = await prisma.conversationMember.findFirst({
      where: { conversationId, leftAt: null, role: 'ADMIN' },
      orderBy: { joinedAt: 'asc' },
    });
    const next =
      successor ??
      (await prisma.conversationMember.findFirst({
        where: { conversationId, leftAt: null, role: 'MEMBER' },
        orderBy: { joinedAt: 'asc' },
      }));
    if (next) {
      await prisma.conversationMember.update({ where: { id: next.id }, data: { role: 'OWNER' } });
    }
  }

  await postSystemMessage(conversationId, `${target.user.name} left the group`);
  getIo().to(conversationRoom(conversationId)).emit('conversation:member-removed', { conversationId, userId: targetUserId });
}

export async function removeMember(conversationId: string, actingUserId: string, targetUserId: string): Promise<void> {
  await assertGroup(conversationId);
  await assertRole(conversationId, actingUserId, ['OWNER', 'ADMIN']);
  await departMember(conversationId, targetUserId);
}

export async function leaveConversation(conversationId: string, userId: string): Promise<void> {
  await assertGroup(conversationId);
  await assertMembership(conversationId, userId);
  await departMember(conversationId, userId);
}
