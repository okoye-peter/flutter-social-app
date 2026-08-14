import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import { authRouter } from './routes/auth.js';
import { notificationsRouter } from './routes/notifications.js';
import { errorHandler } from './middleware/error-handler.js';

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/auth', authRouter);
app.use('/api/notifications', notificationsRouter);

app.use(errorHandler);

const port = process.env.PORT ?? 3000;
app.listen(port, () => console.log(`Server listening on port ${port}`));
