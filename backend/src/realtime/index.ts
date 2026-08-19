import type { Server as HttpServer } from 'node:http';
import { Server } from 'socket.io';
import { setIo } from './io.js';
import { socketAuthMiddleware } from './auth.js';
import { registerConnectionHandlers } from './connection.js';

export function initRealtime(httpServer: HttpServer): Server {
  const io = new Server(httpServer, { cors: { origin: '*' } }); // mirrors the app's existing wide-open cors()
  io.use(socketAuthMiddleware);
  setIo(io);
  registerConnectionHandlers(io);
  return io;
}
