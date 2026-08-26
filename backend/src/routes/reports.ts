import { Router } from 'express';
import * as reportController from '../controllers/report.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { createReportSchema } from '../schemas/report.schema.js';

export const reportsRouter = Router();

reportsRouter.post('/', requireAuth, validate(createReportSchema), reportController.createReport);
