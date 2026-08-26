import type { Server, Socket } from 'socket.io';
import { prisma } from '../prisma.js';
import { addSocket, removeSocket } from './presence.js';
import { conversationRoom, userRoom } from './rooms.js';
import { registerTypingHandlers } from './handlers/typing.js';
import { registerCallHandlers } from './handlers/call.js';

export function registerConnectionHandlers(io: Server): void {
  io.on('connection', (socket: Socket) => {
    void handleConnection(io, socket);
  });
}

async function handleConnection(io: Server, socket: Socket): Promise<void> {
  const userId = socket.data.userId as string;

  socket.join(userRoom(userId));

  const memberships = await prisma.conversationMember.findMany({
    where: { userId, leftAt: null },
    select: { conversationId: true },
  });
  const conversationIds = memberships.map((m) => m.conversationId);
  for (const conversationId of conversationIds) {
    socket.join(conversationRoom(conversationId));
  }

  const isFirstConnection = addSocket(userId, socket.id);
  if (isFirstConnection) {
    await prisma.user.update({ where: { id: userId }, data: { isOnline: true } });
    for (const conversationId of conversationIds) {
      socket.to(conversationRoom(conversationId)).emit('presence:update', { userId, isOnline: true });
    }
  }

  registerTypingHandlers(socket);
  registerCallHandlers(io, socket);

  socket.on('disconnect', () => {
    void handleDisconnect(socket, userId, conversationIds);
  });
}

async function handleDisconnect(socket: Socket, userId: string, conversationIds: string[]): Promise<void> {
  const isLastConnection = removeSocket(userId, socket.id);
  if (!isLastConnection) return;

  const lastSeen = new Date();
  await prisma.user.update({ where: { id: userId }, data: { isOnline: false, lastSeen } });
  for (const conversationId of conversationIds) {
    socket.to(conversationRoom(conversationId)).emit('presence:update', { userId, isOnline: false, lastSeen });
  }
}
