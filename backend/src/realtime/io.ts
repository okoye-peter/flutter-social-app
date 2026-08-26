import type { Server } from 'socket.io';

let io: Server | undefined;

export function setIo(instance: Server): void {
  io = instance;
}

export function getIo(): Server {
  if (!io) {
    throw new Error('Socket.IO server not initialized yet');
  }
  return io;
}
