import 'dotenv/config';
import http from 'node:http';
import cors from 'cors';
import express from 'express';
import { authRouter } from './routes/auth.js';
import { notificationsRouter } from './routes/notifications.js';
import { usersRouter } from './routes/users.js';
import { postsRouter } from './routes/posts.js';
import { commentsRouter } from './routes/comments.js';
import { conversationsRouter } from './routes/conversations.js';
import { messagesRouter } from './routes/messages.js';
import { reportsRouter } from './routes/reports.js';
import { errorHandler } from './middleware/error-handler.js';
import { initRealtime } from './realtime/index.js';

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/auth', authRouter);
app.use('/api/notifications', notificationsRouter);
app.use('/api/users', usersRouter);
app.use('/api/posts', postsRouter);
app.use('/api/comments', commentsRouter);
app.use('/api/conversations', conversationsRouter);
app.use('/api/messages', messagesRouter);
app.use('/api/reports', reportsRouter);

app.use(errorHandler);

const server = http.createServer(app);
initRealtime(server);

const port = process.env.PORT ?? 3000;
server.listen(port, () => console.log(`Server listening on port ${port}`));
