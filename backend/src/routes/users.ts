import { Router } from 'express';
import * as userController from '../controllers/user.js';
import { requireAuth } from '../middleware/auth.js';
import { uploadProfileImage } from '../middleware/upload.js';

export const usersRouter = Router();

usersRouter.put('/profile', requireAuth, uploadProfileImage.single('image'), userController.updateProfile);

// Must be registered before '/:id' — otherwise Express matches 'blocked' as the :id param.
usersRouter.get('/blocked', requireAuth, userController.listBlocked);

usersRouter.get('/:id', requireAuth, userController.getProfile);
usersRouter.get('/:id/posts', requireAuth, userController.listUserPosts);
usersRouter.get('/:id/reels', requireAuth, userController.listUserReels);
usersRouter.get('/:id/reposts', requireAuth, userController.listUserReposts);
usersRouter.get('/:id/tagged', requireAuth, userController.listUserTagged);

usersRouter.post('/:id/follow', requireAuth, userController.follow);
usersRouter.delete('/:id/follow', requireAuth, userController.unfollow);
usersRouter.get('/:id/followers', requireAuth, userController.listFollowers);
usersRouter.get('/:id/following', requireAuth, userController.listFollowing);

usersRouter.post('/:id/block', requireAuth, userController.block);
usersRouter.delete('/:id/block', requireAuth, userController.unblock);
