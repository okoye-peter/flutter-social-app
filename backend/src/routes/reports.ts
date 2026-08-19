import { Router } from 'express';
import * as reportController from '../controllers/report.js';
import { requireAuth } from '../middleware/auth.js';

export const reportsRouter = Router();

reportsRouter.post('/', requireAuth, reportController.createReport);
