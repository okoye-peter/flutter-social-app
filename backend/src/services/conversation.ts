import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { decodeCursor, encodeCursor, buildCursorWhere, toPage, parseLimit, type CursorPage } from '../lib/pagination.js';
import { assertNotBlocked, isBlocked } from './block.js';
import { toSafeUser, type SafeUser } from './auth.js';
import { uploadImage } from './cloudinary.js';
import { joinUserToConversation, leaveUserFromConversation } from '../realtime/rooms.js';
import { getIo } from '../realtime/io.js';
import { conversationRoom } from '../realtime/rooms.js';
import type {
  Conversation,
  ConversationMember,
  ConversationType,
  Message,
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

// Shared by sendMessage and getUploadAuth: a caller must be an active member
// and, for a DIRECT thread, not blocked by/blocking the other participant.
// An existing GROUP's ongoing membership isn't re-policed beyond
// assertMembership here — addMembers is the actual gate for group
// membership/blocks, same rationale as sendMessage previously inlined.
export async function assertCanPostToConversation(conversationId: string, userId: string): Promise<void> {
  await assertMembership(conversationId, userId);

  const conversation = await prisma.conversation.findUnique({
    where: { id: conversationId },
    select: { type: true },
  });
  if (conversation?.type === 'DIRECT') {
    const otherMember = await prisma.conversationMember.findFirst({
      where: { conversationId, userId: { not: userId } },
      select: { userId: true },
    });
    if (otherMember) await assertNotBlocked(otherMember.userId, userId);
  }
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
  // Membership events only happen in groups.
  getIo().to(conversationRoom(conversationId)).emit('message:new', { message, conversationType: 'GROUP' });
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
    await assertNotBlocked(targetId, creatorId);

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

// Shared by listMyConversations and listDirectChats: fetches the viewer's
// conversation page (optionally narrowed by type/other-member-name) plus the
// per-conversation lastReadAt needed to compute unread counts.
async function queryConversationPage(
  viewerId: string,
  query: { cursor?: string; limit?: string },
  typeFilter?: ConversationType,
  nameQuery?: string,
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
      ...(typeFilter ? { type: typeFilter } : {}),
      ...(nameQuery
        ? typeFilter === 'GROUP'
          ? { name: { contains: nameQuery, mode: 'insensitive' } }
          : {
              members: {
                some: {
                  userId: { not: viewerId },
                  leftAt: null,
                  user: {
                    OR: [
                      { name: { contains: nameQuery, mode: 'insensitive' } },
                      { username: { contains: nameQuery, mode: 'insensitive' } },
                    ],
                  },
                },
              },
            }
        : {}),
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

  return { page, nextCursor, lastReadByConversation };
}

async function unreadCountFor(conversationId: string, viewerId: string, lastReadAt: Date | null | undefined): Promise<number> {
  return prisma.message.count({
    where: {
      conversationId,
      createdAt: { gt: lastReadAt ?? new Date(0) },
      senderId: { not: viewerId },
      deletedAt: null,
    },
  });
}

export async function listMyConversations(
  viewerId: string,
  query: { cursor?: string; limit?: string },
) {
  const { page, nextCursor, lastReadByConversation } = await queryConversationPage(viewerId, query);

  const items = await Promise.all(
    page.map(async (conversation) => {
      const unreadCount = await unreadCountFor(conversation.id, viewerId, lastReadByConversation.get(conversation.id));
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

export interface DirectChatItem {
  conversationId: string;
  user: SafeUser;
  lastMessage: Message | null;
  unreadCount: number;
  lastMessageAt: Date | null;
}

// The "chat list" view: one row per person the viewer has a DIRECT
// conversation with, showing that person (not the raw member list) plus
// their unread count — as opposed to listMyConversations, which also
// includes GROUP conversations and returns the full member list.
//
// An optional `q` filters this down to chats whose other participant's name
// or username matches — this is the inbox search (search within chats you
// already have), as opposed to searchContacts below (search to start a new
// one). Mirrors how WhatsApp/Instagram split "search my chats" from
// "find someone new to message" into two separate flows.
export async function listDirectChats(
  viewerId: string,
  query: { cursor?: string; limit?: string; q?: string },
): Promise<CursorPage<DirectChatItem>> {
  const q = (query.q ?? '').trim() || undefined;
  const { page, nextCursor, lastReadByConversation } = await queryConversationPage(viewerId, query, 'DIRECT', q);

  const items = await Promise.all(
    page.map(async (conversation) => {
      const unreadCount = await unreadCountFor(conversation.id, viewerId, lastReadByConversation.get(conversation.id));
      // A DIRECT conversation always has exactly its two original members
      // (see createConversation) and members can't leave one (leaveConversation
      // only supports GROUP) — so the other member always exists.
      const otherMember = conversation.members.find((m) => m.userId !== viewerId)!;
      return {
        conversationId: conversation.id,
        user: toSafeUser(otherMember.user),
        lastMessage: conversation.messages[0] ?? null,
        unreadCount,
        lastMessageAt: conversation.lastMessageAt,
      };
    }),
  );

  return { items, nextCursor };
}

export interface GroupChatItem {
  conversationId: string;
  name: string | null;
  image: string | null;
  visibility: GroupVisibility | null;
  memberCount: number;
  lastMessage: Message | null;
  unreadCount: number;
  lastMessageAt: Date | null;
}

// The "my groups" inbox view: one row per GROUP conversation the viewer is
// currently a member of, PUBLIC or PRIVATE alike — membership is the only
// gate. As opposed to searchGroups below, which discovers PUBLIC groups the
// viewer is NOT yet in.
//
// An optional `q` filters this down to groups whose own name matches — inbox
// search within groups you already belong to, not discovery.
export async function listMyGroups(
  viewerId: string,
  query: { cursor?: string; limit?: string; q?: string },
): Promise<CursorPage<GroupChatItem>> {
  const q = (query.q ?? '').trim() || undefined;
  const { page, nextCursor, lastReadByConversation } = await queryConversationPage(viewerId, query, 'GROUP', q);

  const items = await Promise.all(
    page.map(async (conversation) => {
      const unreadCount = await unreadCountFor(conversation.id, viewerId, lastReadByConversation.get(conversation.id));
      return {
        conversationId: conversation.id,
        name: conversation.name,
        image: conversation.image,
        visibility: conversation.visibility,
        memberCount: conversation.members.length,
        lastMessage: conversation.messages[0] ?? null,
        unreadCount,
        lastMessageAt: conversation.lastMessageAt,
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

  const addedUserIds: string[] = [];
  for (const user of existingUsers) {
    if (await isBlocked(user.id, userId)) continue; // silently skip — not a hard error for a bulk-add call

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
        addedUserIds.push(user.id);
      }
      continue; // already an active member — no-op
    }
    await prisma.conversationMember.create({ data: { conversationId, userId: user.id, role: 'MEMBER' } });
    joinUserToConversation(user.id, conversationId);
    await postSystemMessage(conversationId, `${user.name} was added to the group`);
    addedUserIds.push(user.id);
  }

  if (addedUserIds.length > 0) {
    getIo().to(conversationRoom(conversationId)).emit('conversation:member-added', { conversationId, memberIds: addedUserIds });
  }

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

export type GroupJoinStatus = 'PENDING' | 'NONE';

export interface GroupSearchResult {
  id: string;
  name: string | null;
  image: string | null;
  visibility: GroupVisibility | null;
  memberCount: number;
  createdAt: Date;
  joinStatus: GroupJoinStatus;
}

// Discovery: groups the viewer is NOT yet a member of, PUBLIC and PRIVATE
// alike (already-joined groups belong in listMyGroups instead, not here).
// The client decides how to join based on `visibility` — PUBLIC groups join
// immediately via joinGroup, PRIVATE ones go through joinGroup too but land
// as a pending GroupJoinRequest that an OWNER/ADMIN must approve or reject
// (see listJoinRequests/respondToJoinRequest) — same as WhatsApp/Instagram's
// public-vs-private-group join flow.
export async function searchGroups(
  viewerId: string,
  query: { q?: string; cursor?: string; limit?: string },
): Promise<CursorPage<GroupSearchResult>> {
  const q = (query.q ?? '').trim();
  if (!q) return { items: [], nextCursor: null };

  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const rows = await prisma.conversation.findMany({
    where: {
      type: 'GROUP',
      name: { contains: q, mode: 'insensitive' },
      NOT: { members: { some: { userId: viewerId, leftAt: null } } },
      ...buildCursorWhere(cursor),
    },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    include: { _count: { select: { members: { where: { leftAt: null } } } } },
  });

  const page = toPage(rows, limit);
  const ids = page.items.map((c) => c.id);

  const pendingRequests = await prisma.groupJoinRequest.findMany({
    where: { conversationId: { in: ids }, userId: viewerId, status: 'PENDING' },
    select: { conversationId: true },
  });
  const pendingFor = new Set(pendingRequests.map((r) => r.conversationId));

  return {
    items: page.items.map(({ _count, ...row }) => ({
      id: row.id,
      name: row.name,
      image: row.image,
      visibility: row.visibility,
      memberCount: _count.members,
      createdAt: row.createdAt,
      joinStatus: pendingFor.has(row.id) ? 'PENDING' : 'NONE',
    })),
    nextCursor: page.nextCursor,
  };
}

export interface ContactSearchResult extends SafeUser {
  isFollowedByMe: boolean;
  followsMe: boolean;
  // Set when the viewer already has a DIRECT conversation with this person —
  // lets the client open it instead of creating a duplicate one.
  conversationId: string | null;
}

// People the viewer can start (or already has) a DIRECT conversation with:
// the union of who they follow and who follows them, optionally filtered by
// a name/username query. Unlike users.searchUsers (which searches everyone),
// this is scoped to the viewer's follow graph since that's who they'd
// plausibly want to message.
export async function searchContacts(
  viewerId: string,
  query: { q?: string; cursor?: string; limit?: string },
): Promise<CursorPage<ContactSearchResult>> {
  const q = (query.q ?? '').trim();
  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const [following, followers] = await Promise.all([
    prisma.follow.findMany({ where: { followerId: viewerId }, select: { followingId: true } }),
    prisma.follow.findMany({ where: { followingId: viewerId }, select: { followerId: true } }),
  ]);
  const followingSet = new Set(following.map((f) => f.followingId));
  const followerSet = new Set(followers.map((f) => f.followerId));
  const contactIds = [...new Set([...followingSet, ...followerSet])];
  if (contactIds.length === 0) return { items: [], nextCursor: null };

  const rows = await prisma.user.findMany({
    where: {
      id: { in: contactIds },
      AND: [
        ...(q
          ? [{ OR: [{ name: { contains: q, mode: 'insensitive' as const } }, { username: { contains: q, mode: 'insensitive' as const } }] }]
          : []),
        // Hide both directions of a block, same as users.searchUsers.
        {
          NOT: {
            OR: [
              { blocking: { some: { blockedId: viewerId } } },
              { blockedBy: { some: { blockerId: viewerId } } },
            ],
          },
        },
        buildCursorWhere(cursor),
      ],
    },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
  });

  const page = toPage(rows, limit);
  const ids = page.items.map((u) => u.id);

  const existingDirects = await prisma.conversation.findMany({
    where: {
      type: 'DIRECT',
      members: { some: { userId: viewerId, leftAt: null } },
      AND: [{ members: { some: { userId: { in: ids }, leftAt: null } } }],
    },
    select: { id: true, members: { where: { leftAt: null }, select: { userId: true } } },
  });
  const conversationIdByUser = new Map<string, string>();
  for (const c of existingDirects) {
    const other = c.members.find((m) => m.userId !== viewerId);
    if (other) conversationIdByUser.set(other.userId, c.id);
  }

  return {
    items: page.items.map((u) => ({
      ...toSafeUser(u),
      isFollowedByMe: followingSet.has(u.id),
      followsMe: followerSet.has(u.id),
      conversationId: conversationIdByUser.get(u.id) ?? null,
    })),
    nextCursor: page.nextCursor,
  };
}

// Self-service join: PUBLIC groups add the caller immediately, PRIVATE
// groups create a pending request an OWNER/ADMIN must act on.
export async function joinGroup(
  conversationId: string,
  userId: string,
): Promise<{ status: 'JOINED' | 'REQUESTED'; conversation?: ConversationDTO }> {
  const conversation = await assertGroup(conversationId);

  const existingMember = await prisma.conversationMember.findUnique({
    where: { conversationId_userId: { conversationId, userId } },
  });
  if (existingMember && existingMember.leftAt === null) {
    throw new HttpError(400, 'You are already a member of this group');
  }

  if (conversation.visibility === 'PRIVATE') {
    const existingRequest = await prisma.groupJoinRequest.findUnique({
      where: { conversationId_userId: { conversationId, userId } },
    });
    if (existingRequest?.status === 'PENDING') {
      throw new HttpError(400, 'You already have a pending request to join this group');
    }
    await prisma.groupJoinRequest.upsert({
      where: { conversationId_userId: { conversationId, userId } },
      create: { conversationId, userId },
      update: { status: 'PENDING', respondedAt: null },
    });
    return { status: 'REQUESTED' };
  }

  const user = await prisma.user.findUnique({ where: { id: userId }, select: { name: true } });
  if (!user) throw new HttpError(404, 'User not found');

  if (existingMember) {
    await prisma.conversationMember.update({
      where: { id: existingMember.id },
      data: { leftAt: null, role: 'MEMBER', joinedAt: new Date() },
    });
  } else {
    const currentCount = await prisma.conversationMember.count({ where: { conversationId, leftAt: null } });
    if (currentCount + 1 > MAX_GROUP_MEMBERS) {
      throw new HttpError(400, `A group can have at most ${MAX_GROUP_MEMBERS} members`);
    }
    await prisma.conversationMember.create({ data: { conversationId, userId, role: 'MEMBER' } });
  }

  joinUserToConversation(userId, conversationId);
  await postSystemMessage(conversationId, `${user.name} joined the group`);
  getIo().to(conversationRoom(conversationId)).emit('conversation:member-added', { conversationId, memberIds: [userId] });

  return { status: 'JOINED', conversation: await toConversationDTO(conversationId) };
}

export async function cancelJoinRequest(conversationId: string, userId: string): Promise<void> {
  await assertGroup(conversationId);
  await prisma.groupJoinRequest.deleteMany({ where: { conversationId, userId, status: 'PENDING' } });
}

export interface JoinRequestDTO {
  id: string;
  user: SafeUser;
  createdAt: Date;
}

export async function listJoinRequests(conversationId: string, actingUserId: string): Promise<JoinRequestDTO[]> {
  await assertGroup(conversationId);
  await assertRole(conversationId, actingUserId, ['OWNER', 'ADMIN']);

  const rows = await prisma.groupJoinRequest.findMany({
    where: { conversationId, status: 'PENDING' },
    orderBy: { createdAt: 'asc' },
    include: { user: true },
  });
  return rows.map((r) => ({ id: r.id, user: toSafeUser(r.user), createdAt: r.createdAt }));
}

export async function respondToJoinRequest(
  conversationId: string,
  actingUserId: string,
  requestId: string,
  accept: boolean,
): Promise<void> {
  await assertGroup(conversationId);
  await assertRole(conversationId, actingUserId, ['OWNER', 'ADMIN']);

  const request = await prisma.groupJoinRequest.findFirst({
    where: { id: requestId, conversationId, status: 'PENDING' },
    include: { user: { select: { name: true } } },
  });
  if (!request) throw new HttpError(404, 'Join request not found');

  if (!accept) {
    await prisma.groupJoinRequest.update({
      where: { id: request.id },
      data: { status: 'REJECTED', respondedAt: new Date() },
    });
    return;
  }

  const currentCount = await prisma.conversationMember.count({ where: { conversationId, leftAt: null } });
  if (currentCount + 1 > MAX_GROUP_MEMBERS) {
    throw new HttpError(400, `A group can have at most ${MAX_GROUP_MEMBERS} members`);
  }

  await prisma.$transaction([
    prisma.groupJoinRequest.update({
      where: { id: request.id },
      data: { status: 'ACCEPTED', respondedAt: new Date() },
    }),
    prisma.conversationMember.upsert({
      where: { conversationId_userId: { conversationId, userId: request.userId } },
      create: { conversationId, userId: request.userId, role: 'MEMBER' },
      update: { leftAt: null, role: 'MEMBER', joinedAt: new Date() },
    }),
  ]);

  joinUserToConversation(request.userId, conversationId);
  await postSystemMessage(conversationId, `${request.user.name} joined the group`);
  getIo()
    .to(conversationRoom(conversationId))
    .emit('conversation:member-added', { conversationId, memberIds: [request.userId] });
}
