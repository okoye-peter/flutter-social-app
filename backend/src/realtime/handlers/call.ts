import type { Server, Socket } from 'socket.io';
import * as callService from '../../services/call.js';
import { createNotification } from '../../services/notifications.js';
import { callRoom, conversationRoom, userRoom } from '../rooms.js';

function errorMessage(err: unknown, fallback: string): string {
  return err instanceof Error ? err.message : fallback;
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
      for (const inviteeId of call.inviteeIds) {
        io.to(userRoom(inviteeId)).emit('call:incoming', {
          callId: call.id,
          conversationId,
          type: call.type,
          initiatorId: userId,
        });
        await createNotification({ userId: inviteeId, actorId: userId, type: 'CALL', conversationId });
      }
    } catch (err) {
      socket.emit('call:error', { message: errorMessage(err, 'Failed to start call') });
    }
  });

  socket.on('call:accept', async (payload: { callId?: string }) => {
    const { callId } = payload ?? {};
    if (!callId) return;
    try {
      await callService.acceptCall(callId, userId);
      socket.join(callRoom(callId));
      io.to(callRoom(callId)).emit('call:participant-joined', { callId, userId });
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
