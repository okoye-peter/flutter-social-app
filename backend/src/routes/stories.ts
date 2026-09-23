import { Router } from 'express';
import * as storyController from '../controllers/story.js';
import { requireAuth } from '../middleware/auth.js';
import { uploadStoryMedia } from '../middleware/upload.js';
import { validate } from '../middleware/validate.js';
import { checkCreateStoryFileRequired, createStorySchema } from '../schemas/story.schema.js';

export const storiesRouter = Router();

/**
 * @openapi
 * /stories:
 *   post:
 *     summary: Post a new story
 *     description: Expires 24 hours after posting. Requires image or video media.
 *     tags: [Stories]
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required: [media]
 *             properties:
 *               caption: { type: string, description: 'Max 500 characters.' }
 *               media: { type: string, format: binary }
 *     responses:
 *       201:
 *         description: The created story.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { story: { $ref: '#/components/schemas/Story' } } }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *   get:
 *     summary: Get the stories feed
 *     description: >
 *       Active (non-expired) stories from the caller and everyone they follow, grouped by author.
 *       The caller's own group comes first; others are ordered unseen-first, then most recent.
 *     tags: [Stories]
 *     responses:
 *       200:
 *         description: Story groups.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties: { groups: { type: array, items: { $ref: '#/components/schemas/StoryGroup' } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
storiesRouter.post(
  '/',
  requireAuth,
  uploadStoryMedia.single('media'),
  validate(createStorySchema, { withFile: checkCreateStoryFileRequired }),
  storyController.createStory,
);
storiesRouter.get('/', requireAuth, storyController.listStoriesFeed);

/**
 * @openapi
 * /stories/{id}:
 *   get:
 *     summary: Get a single story
 *     description: 404s once the story has expired.
 *     tags: [Stories]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The story.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { story: { $ref: '#/components/schemas/Story' } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 *       404: { $ref: '#/components/responses/NotFound' }
 *   delete:
 *     summary: Delete a story
 *     description: Only the story's own author can delete it. Idempotent.
 *     tags: [Stories]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       204: { description: 'Deleted.' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 */
storiesRouter.get('/:id', requireAuth, storyController.getStory);
storiesRouter.delete('/:id', requireAuth, storyController.deleteStory);

/**
 * @openapi
 * /stories/{id}/views:
 *   post:
 *     summary: Mark a story as viewed by the caller
 *     description: No-op for the story's own author (owners don't "view" their own story). Idempotent.
 *     tags: [Stories]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       204: { description: 'Recorded.' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 *       404: { $ref: '#/components/responses/NotFound' }
 *   get:
 *     summary: List who has viewed a story
 *     description: Only the story's own author can see its viewers.
 *     tags: [Stories]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Viewers, most recent first.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 viewers:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       viewer: { $ref: '#/components/schemas/SafeUser' }
 *                       viewedAt: { type: string, format: date-time }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { description: 'Only the story owner can see its viewers.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
storiesRouter.post('/:id/views', requireAuth, storyController.markStoryViewed);
storiesRouter.get('/:id/views', requireAuth, storyController.listStoryViewers);
