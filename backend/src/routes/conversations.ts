import { Router } from 'express';
import * as conversationController from '../controllers/conversation.js';
import { requireAuth } from '../middleware/auth.js';
import { uploadProfileImage, uploadChatAttachment } from '../middleware/upload.js';
import { validate } from '../middleware/validate.js';
import {
  addMembersSchema,
  createConversationSchema,
  markReadSchema,
  updateConversationSchema,
} from '../schemas/conversation.schema.js';
import { checkSendMessageFile, sendMessageSchema } from '../schemas/message.schema.js';

export const conversationsRouter = Router();

conversationsRouter.post(
  '/',
  requireAuth,
  uploadProfileImage.single('image'),
  validate(createConversationSchema),
  conversationController.createConversation,
);
conversationsRouter.get('/', requireAuth, conversationController.listMyConversations);

conversationsRouter.get('/:id', requireAuth, conversationController.getConversation);
conversationsRouter.put(
  '/:id',
  requireAuth,
  uploadProfileImage.single('image'),
  validate(updateConversationSchema),
  conversationController.updateConversation,
);

conversationsRouter.post('/:id/members', requireAuth, validate(addMembersSchema), conversationController.addMembers);
conversationsRouter.delete('/:id/members/:userId', requireAuth, conversationController.removeMember);
conversationsRouter.post('/:id/leave', requireAuth, conversationController.leaveConversation);

conversationsRouter.get('/:id/messages', requireAuth, conversationController.listMessages);
conversationsRouter.post(
  '/:id/messages',
  requireAuth,
  uploadChatAttachment.single('file'),
  validate(sendMessageSchema, { withFile: checkSendMessageFile }),
  conversationController.sendMessage,
);

conversationsRouter.post('/:id/read', requireAuth, validate(markReadSchema), conversationController.markRead);

conversationsRouter.get('/:id/pins', requireAuth, conversationController.listPinned);

conversationsRouter.get('/:id/calls', requireAuth, conversationController.listCalls);
