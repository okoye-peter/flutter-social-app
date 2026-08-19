import { Router } from 'express';
import * as postController from '../controllers/post.js';
import { requireAuth } from '../middleware/auth.js';
import { uploadPostMedia } from '../middleware/upload.js';

export const postsRouter = Router();

postsRouter.post('/', requireAuth, uploadPostMedia.single('media'), postController.createPost);
postsRouter.get('/', requireAuth, postController.listFeed);

// Must be registered before '/:id' — otherwise Express matches 'bookmarks' as the :id param.
postsRouter.get('/bookmarks', requireAuth, postController.listMyBookmarks);

postsRouter.get('/:id', requireAuth, postController.getPost);
postsRouter.delete('/:id', requireAuth, postController.deletePost);

postsRouter.get('/:id/comments', requireAuth, postController.listComments);
postsRouter.post('/:id/comments', requireAuth, postController.createComment);

postsRouter.post('/:id/likes', requireAuth, postController.likePost);
postsRouter.delete('/:id/likes', requireAuth, postController.unlikePost);

postsRouter.post('/:id/bookmarks', requireAuth, postController.bookmarkPost);
postsRouter.delete('/:id/bookmarks', requireAuth, postController.unbookmarkPost);

postsRouter.post('/:id/reposts', requireAuth, postController.repost);
postsRouter.delete('/:id/reposts', requireAuth, postController.unrepost);

postsRouter.post('/:id/tags', requireAuth, postController.addTags);
postsRouter.delete('/:id/tags/:userId', requireAuth, postController.removeTag);
