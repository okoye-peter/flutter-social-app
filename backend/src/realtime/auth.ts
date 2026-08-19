import type { Socket } from 'socket.io';
import { verifyAccessToken } from '../lib/jwt.js';

export function socketAuthMiddleware(socket: Socket, next: (err?: Error) => void): void {
  const header = socket.handshake.headers.authorization;
  const token =
    (socket.handshake.auth?.token as string | undefined) ??
    (header?.startsWith('Bearer ') ? header.slice('Bearer '.length) : undefined);

  if (!token) {
    return next(new Error('Missing bearer token'));
  }

  try {
    socket.data.userId = verifyAccessToken(token);
    next();
  } catch {
    next(new Error('Invalid or expired token'));
  }
}
