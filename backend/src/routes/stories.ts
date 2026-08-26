import { Router } from 'express';
import * as storyController from '../controllers/story.js';
import { requireAuth } from '../middleware/auth.js';
import { uploadStoryMedia } from '../middleware/upload.js';
import { validate } from '../middleware/validate.js';
import { checkCreateStoryFileRequired, createStorySchema } from '../schemas/story.schema.js';

export const storiesRouter = Router();

storiesRouter.post(
  '/',
  requireAuth,
  uploadStoryMedia.single('media'),
  validate(createStorySchema, { withFile: checkCreateStoryFileRequired }),
  storyController.createStory,
);
storiesRouter.get('/', requireAuth, storyController.listStoriesFeed);

storiesRouter.get('/:id', requireAuth, storyController.getStory);
storiesRouter.delete('/:id', requireAuth, storyController.deleteStory);

storiesRouter.post('/:id/views', requireAuth, storyController.markStoryViewed);
storiesRouter.get('/:id/views', requireAuth, storyController.listStoryViewers);
