// Single-process in-memory presence tracker. Correct for one Socket.IO
// instance; if this app ever runs multiple server processes, this Map needs
// replacing with a shared store (e.g. ioredis + @socket.io/redis-adapter) so
// presence is consistent across instances. Not building for that now —
// intentionally out of scope until there's a real multi-instance need.
const socketsByUser = new Map<string, Set<string>>();

export function addSocket(userId: string, socketId: string): boolean {
  let sockets = socketsByUser.get(userId);
  if (!sockets) {
    sockets = new Set();
    socketsByUser.set(userId, sockets);
  }
  const wasEmpty = sockets.size === 0;
  sockets.add(socketId);
  return wasEmpty; // true => this is the user's first active connection
}

export function removeSocket(userId: string, socketId: string): boolean {
  const sockets = socketsByUser.get(userId);
  if (!sockets) return false;
  sockets.delete(socketId);
  if (sockets.size === 0) {
    socketsByUser.delete(userId);
    return true; // true => that was the user's last active connection
  }
  return false;
}

export function getSocketIds(userId: string): string[] {
  return [...(socketsByUser.get(userId) ?? [])];
}

export function isOnline(userId: string): boolean {
  return socketsByUser.has(userId);
}
