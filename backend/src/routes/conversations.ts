import { Router } from 'express';
import * as conversationController from '../controllers/conversation.js';
import { requireAuth } from '../middleware/auth.js';
import { uploadProfileImage, uploadChatAttachment } from '../middleware/upload.js';

export const conversationsRouter = Router();

conversationsRouter.post('/', requireAuth, uploadProfileImage.single('image'), conversationController.createConversation);
conversationsRouter.get('/', requireAuth, conversationController.listMyConversations);

conversationsRouter.get('/:id', requireAuth, conversationController.getConversation);
conversationsRouter.put('/:id', requireAuth, uploadProfileImage.single('image'), conversationController.updateConversation);

conversationsRouter.post('/:id/members', requireAuth, conversationController.addMembers);
conversationsRouter.delete('/:id/members/:userId', requireAuth, conversationController.removeMember);
conversationsRouter.post('/:id/leave', requireAuth, conversationController.leaveConversation);

conversationsRouter.get('/:id/messages', requireAuth, conversationController.listMessages);
conversationsRouter.post('/:id/messages', requireAuth, uploadChatAttachment.single('file'), conversationController.sendMessage);

conversationsRouter.post('/:id/read', requireAuth, conversationController.markRead);

conversationsRouter.get('/:id/pins', requireAuth, conversationController.listPinned);

conversationsRouter.get('/:id/calls', requireAuth, conversationController.listCalls);
