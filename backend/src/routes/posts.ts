import { Router } from 'express';
import * as postController from '../controllers/post.js';
import { requireAuth } from '../middleware/auth.js';
import { uploadPostMedia } from '../middleware/upload.js';
import { validate } from '../middleware/validate.js';
import { createCommentSchema } from '../schemas/comment.schema.js';
import { addTagsSchema, checkCreatePostFile, createPostSchema, repostSchema } from '../schemas/post.schema.js';

export const postsRouter = Router();

/**
 * @openapi
 * /posts:
 *   post:
 *     summary: Create a post or reel
 *     description: >
 *       Needs a caption or media (or both). multipart/form-data so an optional image/video can be
 *       attached. A video post cannot also set soundId — it uses its own audio.
 *     tags: [Posts]
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               kind: { type: string, enum: [POST, REEL], default: POST }
 *               caption: { type: string, description: 'Max 2200 characters.' }
 *               soundId: { type: string, description: 'Attach an existing Sound (image posts only).' }
 *               taggedUserIds: { type: string, description: 'JSON-encoded array of user ids, e.g. ["id1","id2"].' }
 *               media: { type: string, format: binary }
 *     responses:
 *       201:
 *         description: The created post.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { post: { $ref: '#/components/schemas/Post' } } }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *   get:
 *     summary: Get the caller's home feed
 *     description: >
 *       Interleaves posts and reposts from people the caller follows (plus their own), newest first.
 *       If that's empty (e.g. a brand-new account following nobody), falls back to a discovery feed of
 *       recent public posts — the response's isDiscovery flag says which mode a page is in, and
 *       pagination stays in that mode across pages via the cursor.
 *     tags: [Posts]
 *     parameters:
 *       - in: query
 *         name: kind
 *         schema: { type: string, enum: [POST, REEL] }
 *         description: Omit to include both.
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A feed page.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       post: { $ref: '#/components/schemas/Post' }
 *                       repost:
 *                         nullable: true
 *                         allOf:
 *                           - $ref: '#/components/schemas/Repost'
 *                           - type: object
 *                             properties: { repostedBy: { $ref: '#/components/schemas/PostAuthor' } }
 *                 nextCursor: { type: string, nullable: true }
 *                 isDiscovery: { type: boolean }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
postsRouter.post(
  '/',
  requireAuth,
  uploadPostMedia.single('media'),
  validate(createPostSchema, { withFile: checkCreatePostFile }),
  postController.createPost,
);
postsRouter.get('/', requireAuth, postController.listFeed);

// Must be registered before '/:id' — otherwise Express matches 'bookmarks' as the :id param.

/**
 * @openapi
 * /posts/bookmarks:
 *   get:
 *     summary: List the caller's bookmarked posts
 *     tags: [Posts]
 *     parameters:
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of posts.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items: { type: array, items: { $ref: '#/components/schemas/Post' } }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
postsRouter.get('/bookmarks', requireAuth, postController.listMyBookmarks);

/**
 * @openapi
 * /posts/{id}:
 *   get:
 *     summary: Get a single post
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The post.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { post: { $ref: '#/components/schemas/Post' } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 *       404: { $ref: '#/components/responses/NotFound' }
 *   delete:
 *     summary: Delete a post
 *     description: Only the post's own author can delete it. Idempotent.
 *     tags: [Posts]
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
postsRouter.get('/:id', requireAuth, postController.getPost);
postsRouter.delete('/:id', requireAuth, postController.deletePost);

/**
 * @openapi
 * /posts/{id}/sound:
 *   get:
 *     summary: Get (or lazily create) the Sound extracted from a video post's own audio
 *     description: Only valid for VIDEO posts. Creates the Sound row on first request so casual videos don't carry one until someone wants to reuse the audio.
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The sound.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { sound: { $ref: '#/components/schemas/Sound' } } }
 *       400: { description: 'Post has no video audio to use as a sound.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
postsRouter.get('/:id/sound', requireAuth, postController.getPostSound);

/**
 * @openapi
 * /posts/{id}/comments:
 *   get:
 *     summary: List a post's top-level comments
 *     description: Excludes replies — use /comments/{id}/replies for those.
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of comments.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items: { type: array, items: { $ref: '#/components/schemas/Comment' } }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *   post:
 *     summary: Comment on a post (or reply to a comment on it)
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [content]
 *             properties:
 *               content: { type: string, description: 'Max 2000 characters.' }
 *               replyToId: { type: string, description: 'Id of the comment being replied to, if this is a reply.' }
 *     responses:
 *       201:
 *         description: The created comment.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { comment: { $ref: '#/components/schemas/Comment' } } }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
postsRouter.get('/:id/comments', requireAuth, postController.listComments);
postsRouter.post('/:id/comments', requireAuth, validate(createCommentSchema), postController.createComment);

/**
 * @openapi
 * /posts/{id}/likes:
 *   post:
 *     summary: Like a post
 *     description: Idempotent — liking an already-liked post just returns the current count.
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The post's updated like count.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { likesCount: { type: integer } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 *       404: { $ref: '#/components/responses/NotFound' }
 *   delete:
 *     summary: Unlike a post
 *     description: Idempotent — unliking a not-liked post just returns the current count.
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The post's updated like count.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { likesCount: { type: integer } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
postsRouter.post('/:id/likes', requireAuth, postController.likePost);
postsRouter.delete('/:id/likes', requireAuth, postController.unlikePost);

/**
 * @openapi
 * /posts/{id}/bookmarks:
 *   post:
 *     summary: Bookmark a post
 *     description: Idempotent.
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The post's updated bookmark count.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { bookmarksCount: { type: integer } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 *       404: { $ref: '#/components/responses/NotFound' }
 *   delete:
 *     summary: Remove a bookmark
 *     description: Idempotent.
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The post's updated bookmark count.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { bookmarksCount: { type: integer } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
postsRouter.post('/:id/bookmarks', requireAuth, postController.bookmarkPost);
postsRouter.delete('/:id/bookmarks', requireAuth, postController.unbookmarkPost);

/**
 * @openapi
 * /posts/{id}/reposts:
 *   post:
 *     summary: Repost a post, optionally with a quote comment
 *     description: Idempotent — reposting an already-reposted post returns the existing repost as-is.
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       content:
 *         application/json:
 *           schema: { type: object, properties: { comment: { type: string } } }
 *     responses:
 *       201:
 *         description: The repost and the post's updated repost count.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 repost: { $ref: '#/components/schemas/Repost' }
 *                 repostsCount: { type: integer }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 *       404: { $ref: '#/components/responses/NotFound' }
 *   delete:
 *     summary: Remove a repost
 *     description: Idempotent.
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The post's updated repost count.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { repostsCount: { type: integer } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
postsRouter.post('/:id/reposts', requireAuth, validate(repostSchema), postController.repost);
postsRouter.delete('/:id/reposts', requireAuth, postController.unrepost);

/**
 * @openapi
 * /posts/{id}/tags:
 *   post:
 *     summary: Tag people in a post
 *     description: Only the post's own author can tag people. Skips (rather than errors on) ids that don't exist, are already tagged, or are blocked either direction. Max 20 tags per post.
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [userIds]
 *             properties: { userIds: { type: array, items: { type: string } } }
 *     responses:
 *       200:
 *         description: The tags actually created.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 tags:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties: { id: { type: string }, postId: { type: string }, userId: { type: string }, createdAt: { type: string, format: date-time } }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
postsRouter.post('/:id/tags', requireAuth, validate(addTagsSchema), postController.addTags);

/**
 * @openapi
 * /posts/{id}/tags/{userId}:
 *   delete:
 *     summary: Remove a tag from a post
 *     description: Only the post's own author can remove tags. Idempotent.
 *     tags: [Posts]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - in: path
 *         name: userId
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       204: { description: 'Removed.' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
postsRouter.delete('/:id/tags/:userId', requireAuth, postController.removeTag);
