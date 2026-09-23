import { Router } from 'express';
import * as userController from '../controllers/user.js';
import { requireAuth } from '../middleware/auth.js';
import { uploadProfileImage } from '../middleware/upload.js';
import { validate } from '../middleware/validate.js';
import { updateProfileSchema } from '../schemas/user.schema.js';

export const usersRouter = Router();

/**
 * @openapi
 * /users/profile:
 *   put:
 *     summary: Update the caller's own profile
 *     tags: [Users]
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               name: { type: string }
 *               aboutMe: { type: string }
 *               image: { type: string, format: binary }
 *     responses:
 *       200:
 *         description: The updated profile.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { user: { $ref: '#/components/schemas/SafeUser' } } }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
usersRouter.put(
  '/profile',
  requireAuth,
  uploadProfileImage.single('image'),
  validate(updateProfileSchema),
  userController.updateProfile,
);

// Must be registered before '/:id' — otherwise Express matches 'blocked'/'search' as the :id param.

/**
 * @openapi
 * /users/blocked:
 *   get:
 *     summary: List users the caller has blocked
 *     tags: [Users]
 *     parameters:
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of blocked users.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items: { type: array, items: { $ref: '#/components/schemas/SafeUser' } }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
usersRouter.get('/blocked', requireAuth, userController.listBlocked);

/**
 * @openapi
 * /users/search:
 *   get:
 *     summary: Search all users by name or username
 *     description: Unscoped global search — see /conversations/contacts for a search scoped to the caller's follow graph, meant for starting a chat.
 *     tags: [Users]
 *     parameters:
 *       - in: query
 *         name: q
 *         schema: { type: string }
 *         description: Returns no results if omitted or empty.
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of matching users.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items:
 *                   type: array
 *                   items:
 *                     allOf:
 *                       - $ref: '#/components/schemas/SafeUser'
 *                       - type: object
 *                         properties: { isFollowedByMe: { type: boolean }, followsMe: { type: boolean } }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
usersRouter.get('/search', requireAuth, userController.searchUsers);

/**
 * @openapi
 * /users/{id}:
 *   get:
 *     summary: Get a user's public profile
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The profile, from the caller's perspective.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user: { $ref: '#/components/schemas/SafeUser' }
 *                 isFollowedByMe: { type: boolean }
 *                 isBlockedByMe: { type: boolean }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
usersRouter.get('/:id', requireAuth, userController.getProfile);

/**
 * @openapi
 * /users/{id}/posts:
 *   get:
 *     summary: List a user's POST-kind posts
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
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
 *       403: { $ref: '#/components/responses/Forbidden' }
 */
usersRouter.get('/:id/posts', requireAuth, userController.listUserPosts);

/**
 * @openapi
 * /users/{id}/reels:
 *   get:
 *     summary: List a user's REEL-kind posts
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of reels.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items: { type: array, items: { $ref: '#/components/schemas/Post' } }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 */
usersRouter.get('/:id/reels', requireAuth, userController.listUserReels);

/**
 * @openapi
 * /users/{id}/reposts:
 *   get:
 *     summary: List posts a user has reposted
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of the reposted posts (each including the current viewer's like/bookmark/repost state).
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items: { type: array, items: { $ref: '#/components/schemas/Post' } }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 */
usersRouter.get('/:id/reposts', requireAuth, userController.listUserReposts);

/**
 * @openapi
 * /users/{id}/tagged:
 *   get:
 *     summary: List posts a user is tagged in
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
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
 *       403: { $ref: '#/components/responses/Forbidden' }
 */
usersRouter.get('/:id/tagged', requireAuth, userController.listUserTagged);

/**
 * @openapi
 * /users/{id}/follow:
 *   post:
 *     summary: Follow a user
 *     description: Idempotent — following an already-followed user just returns the current count.
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The target's updated follower count.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { followersCount: { type: integer } } }
 *       400: { description: 'Cannot follow yourself.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { description: 'One of you has blocked the other.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *       404: { $ref: '#/components/responses/NotFound' }
 *   delete:
 *     summary: Unfollow a user
 *     description: Idempotent — unfollowing someone not followed just returns the current count.
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The target's updated follower count.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { followersCount: { type: integer } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
usersRouter.post('/:id/follow', requireAuth, userController.follow);
usersRouter.delete('/:id/follow', requireAuth, userController.unfollow);

/**
 * @openapi
 * /users/{id}/followers:
 *   get:
 *     summary: List a user's followers
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of followers.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items: { type: array, items: { $ref: '#/components/schemas/SafeUser' } }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
usersRouter.get('/:id/followers', requireAuth, userController.listFollowers);

/**
 * @openapi
 * /users/{id}/following:
 *   get:
 *     summary: List who a user follows
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of followed users.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items: { type: array, items: { $ref: '#/components/schemas/SafeUser' } }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
usersRouter.get('/:id/following', requireAuth, userController.listFollowing);

/**
 * @openapi
 * /users/{id}/block:
 *   post:
 *     summary: Block a user
 *     description: Idempotent, and also severs any existing follow relationship between the two accounts in both directions.
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       204: { description: 'Blocked.' }
 *       400: { description: 'Cannot block yourself.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *   delete:
 *     summary: Unblock a user
 *     description: Idempotent.
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       204: { description: 'Unblocked.' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
usersRouter.post('/:id/block', requireAuth, userController.block);
usersRouter.delete('/:id/block', requireAuth, userController.unblock);
