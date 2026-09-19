import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { decodeCursor, encodeCursor, parseLimit, type CursorPage } from '../lib/pagination.js';
import { assertMembership } from './conversation.js';
import type { Call, CallType } from '../../generated/prisma/index.js';

// Comfortably past the 45s no-answer expiry (realtime/handlers/call.ts), so
// a RINGING call this old means the expiry timer was lost (server restart).
const STALE_RINGING_MS = 60_000;

export interface InitiatedCall extends Call {
  inviteeIds: string[];
}

export async function initiateCall(conversationId: string, initiatorId: string, type: string): Promise<InitiatedCall> {
  await assertMembership(conversationId, initiatorId);
  if (type !== 'VOICE' && type !== 'VIDEO') {
    throw new HttpError(400, "type must be 'VOICE' or 'VIDEO'");
  }

  const activeCall = await prisma.call.findFirst({
    where: { conversationId, status: { in: ['RINGING', 'ONGOING'] } },
    include: { participants: { select: { status: true } } },
  });
  if (activeCall) {
    // A call only blocks a new one if it's genuinely live. Clients that
    // crash, lose network, or reset without saying goodbye leave "zombie"
    // calls behind (e.g. ONGOING with a single participant), which would
    // otherwise reject every future invite in this conversation forever.
    const joined = activeCall.participants.filter((p) => p.status === 'JOINED').length;
    const isStale =
      activeCall.status === 'RINGING'
        ? Date.now() - activeCall.startedAt.getTime() > STALE_RINGING_MS
        : joined < 2;
    if (!isStale) throw new HttpError(409, 'This conversation already has an active call');

    await prisma.callParticipant.updateMany({ where: { callId: activeCall.id, status: 'JOINED' }, data: { status: 'LEFT', leftAt: new Date() } });
    await prisma.callParticipant.updateMany({ where: { callId: activeCall.id, status: 'INVITED' }, data: { status: 'MISSED' } });
    await prisma.call.update({ where: { id: activeCall.id }, data: { status: 'ENDED', endedAt: new Date() } });
  }

  const members = await prisma.conversationMember.findMany({
    where: { conversationId, leftAt: null },
    select: { userId: true },
  });
  const inviteeIds = members.map((m) => m.userId).filter((id) => id !== initiatorId);
  if (inviteeIds.length === 0) throw new HttpError(400, 'No other members to call');

  const call = await prisma.call.create({
    data: {
      conversationId,
      initiatorId,
      type: type as CallType,
      participants: {
        create: [
          { userId: initiatorId, status: 'JOINED', joinedAt: new Date() },
          ...inviteeIds.map((userId) => ({ userId, status: 'INVITED' as const })),
        ],
      },
    },
  });

  return { ...call, inviteeIds };
}

export async function acceptCall(callId: string, userId: string): Promise<Call> {
  const participant = await prisma.callParticipant.findUnique({ where: { callId_userId: { callId, userId } } });
  if (!participant) throw new HttpError(404, 'Call not found');

  if (participant.status === 'INVITED') {
    await prisma.callParticipant.update({ where: { id: participant.id }, data: { status: 'JOINED', joinedAt: new Date() } });
  }

  const call = await prisma.call.findUniqueOrThrow({ where: { id: callId } });
  if (call.status === 'RINGING') {
    return prisma.call.update({ where: { id: callId }, data: { status: 'ONGOING' } });
  }
  return call;
}

export async function declineCall(callId: string, userId: string): Promise<Call> {
  const participant = await prisma.callParticipant.findUnique({ where: { callId_userId: { callId, userId } } });
  if (!participant) throw new HttpError(404, 'Call not found');

  if (participant.status === 'INVITED') {
    await prisma.callParticipant.update({ where: { id: participant.id }, data: { status: 'DECLINED' } });
  }

  const call = await prisma.call.findUniqueOrThrow({ where: { id: callId } });
  if (call.status === 'RINGING') {
    const stillInvited = await prisma.callParticipant.count({ where: { callId, status: 'INVITED' } });
    if (stillInvited === 0) {
      return prisma.call.update({ where: { id: callId }, data: { status: 'MISSED', endedAt: new Date() } });
    }
  }
  return call;
}

// Auto-transitions a still-RINGING call to MISSED once nobody has answered
// in time. Returns null (no-op) if the call was already answered, ended,
// or expired by the time this runs — callers should only emit a
// call:ended event when this returns non-null.
export async function expireCall(callId: string): Promise<Call | null> {
  const call = await prisma.call.findUnique({ where: { id: callId } });
  if (!call || call.status !== 'RINGING') return null;

  await prisma.callParticipant.updateMany({ where: { callId, status: 'INVITED' }, data: { status: 'MISSED' } });
  return prisma.call.update({ where: { id: callId }, data: { status: 'MISSED', endedAt: new Date() } });
}

// Active (JOINED) participants other than [excludeUserId] — lets a newly
// joining client know who else to send WebRTC offers to, since it has no
// other way to enumerate who's already in the call.
export async function listJoinedParticipantIds(callId: string, excludeUserId: string): Promise<string[]> {
  const rows = await prisma.callParticipant.findMany({
    where: { callId, status: 'JOINED', userId: { not: excludeUserId } },
    select: { userId: true },
  });
  return rows.map((r) => r.userId);
}

export async function leaveCall(callId: string, userId: string): Promise<Call> {
  const participant = await prisma.callParticipant.findUnique({ where: { callId_userId: { callId, userId } } });
  if (!participant) throw new HttpError(404, 'Call not found');

  if (participant.status === 'JOINED') {
    await prisma.callParticipant.update({ where: { id: participant.id }, data: { status: 'LEFT', leftAt: new Date() } });
  }

  const stillJoined = await prisma.callParticipant.count({ where: { callId, status: 'JOINED' } });
  if (stillJoined === 0) {
    return prisma.call.update({ where: { id: callId }, data: { status: 'ENDED', endedAt: new Date() } });
  }
  return prisma.call.findUniqueOrThrow({ where: { id: callId } });
}

export async function endCall(callId: string, userId: string): Promise<Call> {
  const call = await prisma.call.findUnique({ where: { id: callId } });
  if (!call) throw new HttpError(404, 'Call not found');
  if (call.initiatorId !== userId) throw new HttpError(403, 'Only the call initiator can end the call');

  await prisma.callParticipant.updateMany({ where: { callId, status: 'JOINED' }, data: { status: 'LEFT', leftAt: new Date() } });
  await prisma.callParticipant.updateMany({ where: { callId, status: 'INVITED' }, data: { status: 'MISSED' } });

  return prisma.call.update({ where: { id: callId }, data: { status: 'ENDED', endedAt: new Date() } });
}

export async function listCalls(
  conversationId: string,
  viewerId: string,
  query: { cursor?: string; limit?: string },
): Promise<CursorPage<Call>> {
  await assertMembership(conversationId, viewerId);

  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);

  const rows = await prisma.call.findMany({
    where: {
      conversationId,
      ...(cursor
        ? { OR: [{ startedAt: { lt: cursor.createdAt } }, { startedAt: cursor.createdAt, id: { lt: cursor.id } }] }
        : {}),
    },
    orderBy: [{ startedAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
  });

  const hasMore = rows.length > limit;
  const items = hasMore ? rows.slice(0, limit) : rows;
  const last = items.at(-1);
  const nextCursor = hasMore && last ? encodeCursor(last.startedAt, last.id) : null;
  return { items, nextCursor };
}
