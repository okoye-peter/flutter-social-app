import { getIo } from './io.js';
import { getSocketIds } from './presence.js';

export function conversationRoom(conversationId: string): string {
  return `conversation:${conversationId}`;
}

export function userRoom(userId: string): string {
  return `user:${userId}`;
}

export function callRoom(callId: string): string {
  return `call:${callId}`;
}

// Called both from the connection handler (initial join) and from REST
// services when group membership changes, so a user's already-open sockets
// pick up a new conversation room immediately instead of only on reconnect.
export function joinUserToConversation(userId: string, conversationId: string): void {
  const io = getIo();
  const room = conversationRoom(conversationId);
  for (const socketId of getSocketIds(userId)) {
    io.sockets.sockets.get(socketId)?.join(room);
  }
}

export function leaveUserFromConversation(userId: string, conversationId: string): void {
  const io = getIo();
  const room = conversationRoom(conversationId);
  for (const socketId of getSocketIds(userId)) {
    io.sockets.sockets.get(socketId)?.leave(room);
  }
}
