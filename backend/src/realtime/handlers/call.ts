import type { Server, Socket } from 'socket.io';
import { prisma } from '../../prisma.js';
import * as callService from '../../services/call.js';
import { sendCallPush } from '../../services/call-push.js';
import { createNotification } from '../../services/notifications.js';
import { callRoom, conversationRoom, userRoom } from '../rooms.js';

function errorMessage(err: unknown, fallback: string): string {
  return err instanceof Error ? err.message : fallback;
}

// No-answer auto-expiry. In-memory only (lost on server restart, same
// trade-off the rest of this file already accepts for call-room checks) —
// good enough so a caller's UI doesn't ring forever if the callee's device
// never wakes; a restart mid-ring is a rare, low-stakes edge case.
const RING_TIMEOUT_MS = 45_000;

async function expireCallAfterTimeout(io: Server, callId: string, conversationId: string): Promise<void> {
  const expired = await callService.expireCall(callId);
  if (!expired) return; // already answered/ended by the time this fired
  io.to(callRoom(callId)).emit('call:ended', { callId, reason: 'no-answer' });
  io.to(conversationRoom(conversationId)).emit('call:ended', { callId, reason: 'no-answer' });
  io.in(callRoom(callId)).socketsLeave(callRoom(callId));
}

export function registerCallHandlers(io: Server, socket: Socket): void {
  const userId = socket.data.userId as string;

  socket.on('call:invite', async (payload: { conversationId?: string; type?: string }) => {
    const { conversationId, type } = payload ?? {};
    if (!conversationId || !type) return;
    try {
      const call = await callService.initiateCall(conversationId, userId, type);
      socket.join(callRoom(call.id));
      io.to(conversationRoom(conversationId)).emit('call:started', {
        callId: call.id,
        conversationId,
        type: call.type,
        initiatorId: userId,
      });

      const initiator = await prisma.user.findUnique({ where: { id: userId }, select: { name: true } });
      const initiatorName = initiator?.name ?? 'Someone';

      for (const inviteeId of call.inviteeIds) {
        // Always emit regardless of presence — an empty-room .to() emit is
        // already a no-op, and checking presence first would only add a
        // race window (a reconnect landing between the check and the emit).
        io.to(userRoom(inviteeId)).emit('call:incoming', {
          callId: call.id,
          conversationId,
          type: call.type,
          initiatorId: userId,
        });
        // Two different jobs, not merged: createNotification is the
        // persistent record + notification-feed history; sendCallPush is
        // the actual wake-a-backgrounded-app signal. The client dedupes on
        // callId regardless of which path delivered it.
        await createNotification({ userId: inviteeId, actorId: userId, type: 'CALL', conversationId, callId: call.id });
        await sendCallPush(inviteeId, {
          callId: call.id,
          conversationId,
          type: call.type,
          initiatorId: userId,
          initiatorName,
        });
      }

      setTimeout(() => {
        expireCallAfterTimeout(io, call.id, conversationId).catch(() => {});
      }, RING_TIMEOUT_MS);
    } catch (err) {
      socket.emit('call:error', { message: errorMessage(err, 'Failed to start call') });
    }
  });

  socket.on('call:accept', async (payload: { callId?: string }) => {
    const { callId } = payload ?? {};
    if (!callId) return;
    try {
      await callService.acceptCall(callId, userId);
      // Existing participants (joined before this one) let the newly-joining
      // client know who to send WebRTC offers to — the deterministic
      // "new joiner offers to everyone already in the call" rule mesh
      // calling relies on, since the joiner otherwise has no way to
      // enumerate who else is already in the call room.
      const existingParticipantIds = await callService.listJoinedParticipantIds(callId, userId);
      socket.join(callRoom(callId));
      io.to(callRoom(callId)).emit('call:participant-joined', { callId, userId, existingParticipantIds });
    } catch (err) {
      socket.emit('call:error', { message: errorMessage(err, 'Failed to accept call') });
    }
  });

  socket.on('call:decline', async (payload: { callId?: string }) => {
    const { callId } = payload ?? {};
    if (!callId) return;
    try {
      const call = await callService.declineCall(callId, userId);
      io.to(conversationRoom(call.conversationId)).emit('call:declined', { callId, userId });
    } catch (err) {
      socket.emit('call:error', { message: errorMessage(err, 'Failed to decline call') });
    }
  });

  socket.on('call:leave', async (payload: { callId?: string }) => {
    const { callId } = payload ?? {};
    if (!callId) return;
    try {
      await callService.leaveCall(callId, userId);
      io.to(callRoom(callId)).emit('call:participant-left', { callId, userId });
      socket.leave(callRoom(callId));
    } catch (err) {
      socket.emit('call:error', { message: errorMessage(err, 'Failed to leave call') });
    }
  });

  socket.on('call:end', async (payload: { callId?: string }) => {
    const { callId } = payload ?? {};
    if (!callId) return;
    try {
      const call = await callService.endCall(callId, userId);
      io.to(callRoom(callId)).emit('call:ended', { callId, reason: 'ended' });
      io.to(conversationRoom(call.conversationId)).emit('call:ended', { callId, reason: 'ended' });
      io.in(callRoom(callId)).socketsLeave(callRoom(callId));
    } catch (err) {
      socket.emit('call:error', { message: errorMessage(err, 'Failed to end call') });
    }
  });

  // Pure relay — the server never interprets SDP/ICE payloads, it just
  // forwards them to the intended target after confirming the sender is
  // actually part of this call (in-memory room check, not a DB round-trip,
  // since ICE candidates can fire many times per call).
  const relaySignal = (event: string) => (payload: { callId?: string; toUserId?: string; payload?: unknown }) => {
    const { callId, toUserId } = payload ?? {};
    if (!callId || !toUserId) return;
    if (!socket.rooms.has(callRoom(callId))) return;
    io.to(userRoom(toUserId)).emit(event, { callId, fromUserId: userId, payload: payload.payload });
  };

  socket.on('call:offer', relaySignal('call:offer'));
  socket.on('call:answer', relaySignal('call:answer'));
  socket.on('call:ice-candidate', relaySignal('call:ice-candidate'));
}
