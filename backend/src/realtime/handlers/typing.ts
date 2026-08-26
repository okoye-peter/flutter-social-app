import type { Socket } from 'socket.io';
import { conversationRoom } from '../rooms.js';

export function registerTypingHandlers(socket: Socket): void {
  const relay = (isTyping: boolean) => (payload: { conversationId?: string }) => {
    const conversationId = payload?.conversationId;
    if (!conversationId) return;
    const room = conversationRoom(conversationId);
    if (!socket.rooms.has(room)) return; // not a member of this conversation — ignore
    socket.to(room).emit('typing:update', { conversationId, userId: socket.data.userId, isTyping });
  };

  socket.on('typing:start', relay(true));
  socket.on('typing:stop', relay(false));
}
