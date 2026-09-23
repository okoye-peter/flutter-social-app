import { Router } from 'express';
import * as conversationController from '../controllers/conversation.js';
import { requireAuth } from '../middleware/auth.js';
import { uploadProfileImage } from '../middleware/upload.js';
import { validate } from '../middleware/validate.js';
import {
  addMembersSchema,
  createConversationSchema,
  markReadSchema,
  respondJoinRequestSchema,
  updateConversationSchema,
} from '../schemas/conversation.schema.js';
import { checkSendMessageAttachment, sendMessageSchema, uploadAuthSchema } from '../schemas/message.schema.js';

export const conversationsRouter = Router();

/**
 * @openapi
 * /conversations:
 *   post:
 *     summary: Create a DIRECT or GROUP conversation
 *     description: >
 *       For type DIRECT, reuses an existing conversation with participantId if one already exists
 *       instead of creating a duplicate. multipart/form-data so a GROUP can set an image.
 *     tags: [Conversations]
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               type: { type: string, enum: [DIRECT, GROUP], default: DIRECT }
 *               participantId: { type: string, description: 'Required for DIRECT — the other user.' }
 *               name: { type: string, description: 'Required for GROUP.' }
 *               visibility: { type: string, enum: [PRIVATE, PUBLIC], description: 'GROUP only, default PRIVATE.' }
 *               memberIds: { type: string, description: 'GROUP only — JSON-encoded array of user ids to add besides the creator.' }
 *               image: { type: string, format: binary, description: 'GROUP only.' }
 *     responses:
 *       201:
 *         description: The conversation.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { conversation: { $ref: '#/components/schemas/Conversation' } } }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { description: 'Blocked either direction (DIRECT only).', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *   get:
 *     summary: List all of the caller's conversations (DIRECT and GROUP)
 *     description: Includes the full member list per conversation — see /conversations/direct for a simpler, DIRECT-only "chat list" shaped around the other person.
 *     tags: [Conversations]
 *     parameters:
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of conversations.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items:
 *                   type: array
 *                   items:
 *                     allOf:
 *                       - $ref: '#/components/schemas/Conversation'
 *                       - type: object
 *                         properties:
 *                           lastMessage:
 *                             allOf: [{ $ref: '#/components/schemas/Message' }]
 *                             nullable: true
 *                           unreadCount: { type: integer }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
conversationsRouter.post(
  '/',
  requireAuth,
  uploadProfileImage.single('image'),
  validate(createConversationSchema),
  conversationController.createConversation,
);
conversationsRouter.get('/', requireAuth, conversationController.listMyConversations);

// Must be registered before '/:id' — otherwise Express matches 'groups'/'direct'/'contacts' as the :id param.

/**
 * @openapi
 * /conversations/groups/search:
 *   get:
 *     summary: Search groups to discover and join (PUBLIC and PRIVATE)
 *     description: >
 *       Groups matching the name query that the caller is NOT yet a member of — both PUBLIC
 *       and PRIVATE. Already-joined groups never appear here (see /conversations/groups for
 *       those). Join via POST /conversations/{id}/join: PUBLIC groups add the caller
 *       immediately, PRIVATE groups create a pending join request that an OWNER/ADMIN must
 *       approve or reject — reflected here as `joinStatus: PENDING` until they respond.
 *     tags: [Conversations]
 *     parameters:
 *       - in: query
 *         name: q
 *         schema: { type: string }
 *         description: Group name filter. Returns no results if omitted or empty.
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of matching groups the caller can join or has requested to join.
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
 *                       id: { type: string }
 *                       name: { type: string, nullable: true }
 *                       image: { type: string, nullable: true }
 *                       visibility: { type: string, enum: [PRIVATE, PUBLIC], nullable: true }
 *                       memberCount: { type: integer }
 *                       createdAt: { type: string, format: date-time }
 *                       joinStatus: { type: string, enum: [PENDING, NONE] }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
conversationsRouter.get('/groups/search', requireAuth, conversationController.searchGroups);

/**
 * @openapi
 * /conversations/groups:
 *   get:
 *     summary: List the caller's own group chats (PUBLIC and PRIVATE)
 *     description: >
 *       Paginated list of every GROUP conversation the caller is currently a member of,
 *       most recently active first — both PUBLIC and PRIVATE groups are included since
 *       membership is the only gate. Pass `q` to filter by group name within these
 *       existing groups — this is inbox search, not discovery (use
 *       /conversations/groups/search to find new PUBLIC groups to join).
 *     tags: [Conversations]
 *     parameters:
 *       - in: query
 *         name: q
 *         schema: { type: string }
 *         description: Optional filter by group name, scoped to groups the caller already belongs to.
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of the caller's group chats.
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
 *                       conversationId: { type: string }
 *                       name: { type: string, nullable: true }
 *                       image: { type: string, nullable: true }
 *                       visibility: { type: string, enum: [PRIVATE, PUBLIC], nullable: true }
 *                       memberCount: { type: integer }
 *                       lastMessage:
 *                         allOf: [{ $ref: '#/components/schemas/Message' }]
 *                         nullable: true
 *                       unreadCount: { type: integer }
 *                       lastMessageAt: { type: string, format: date-time, nullable: true }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
conversationsRouter.get('/groups', requireAuth, conversationController.listMyGroups);

/**
 * @openapi
 * /conversations/direct:
 *   get:
 *     summary: List (or search within) the caller's direct (1:1) chats
 *     description: >
 *       Paginated list of every person the caller has a DIRECT conversation with, most
 *       recently active first. Each row is the other user, their last message, and how
 *       many of that person's messages the caller hasn't read yet. Pass `q` to search
 *       within these existing chats by the other person's name/username — this is the
 *       inbox search, not a way to find someone new (use /conversations/contacts for that).
 *     tags: [Conversations]
 *     parameters:
 *       - in: query
 *         name: q
 *         schema: { type: string }
 *         description: Optional filter by the other participant's name/username, scoped to existing chats only.
 *       - in: query
 *         name: cursor
 *         schema: { type: string }
 *         description: Opaque pagination cursor from a previous response's nextCursor.
 *       - in: query
 *         name: limit
 *         schema: { type: integer, minimum: 1, maximum: 50, default: 20 }
 *     responses:
 *       200:
 *         description: A page of direct chats.
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
 *                       conversationId: { type: string }
 *                       user: { $ref: '#/components/schemas/SafeUser' }
 *                       lastMessage:
 *                         allOf: [{ $ref: '#/components/schemas/Message' }]
 *                         nullable: true
 *                       unreadCount: { type: integer }
 *                       lastMessageAt: { type: string, format: date-time, nullable: true }
 *                 nextCursor: { type: string, nullable: true }
 *       401:
 *         description: Missing or invalid bearer token.
 */
conversationsRouter.get('/direct', requireAuth, conversationController.listDirectChats);

/**
 * @openapi
 * /conversations/contacts:
 *   get:
 *     summary: Search people you follow or who follow you, to start a chat
 *     description: >
 *       Returns users from the caller's follow graph (people they follow, and people who
 *       follow them), optionally filtered by name/username. Meant for a "new message"
 *       search — separate from /conversations/direct's inbox search — that surfaces
 *       people whether or not the caller has chatted with them before. Each result says
 *       whether a DIRECT conversation already exists with that person so the client can
 *       open it instead of creating a duplicate one.
 *     tags: [Conversations]
 *     parameters:
 *       - in: query
 *         name: q
 *         schema: { type: string }
 *         description: Optional name/username filter. Omit it to list the whole follow graph.
 *       - in: query
 *         name: cursor
 *         schema: { type: string }
 *         description: Opaque pagination cursor from a previous response's nextCursor.
 *       - in: query
 *         name: limit
 *         schema: { type: integer, minimum: 1, maximum: 50, default: 20 }
 *     responses:
 *       200:
 *         description: A page of contacts.
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
 *                         properties:
 *                           isFollowedByMe: { type: boolean }
 *                           followsMe: { type: boolean }
 *                           conversationId:
 *                             type: string
 *                             nullable: true
 *                             description: Existing DIRECT conversation with this user, if any.
 *                 nextCursor: { type: string, nullable: true }
 *       401:
 *         description: Missing or invalid bearer token.
 */
conversationsRouter.get('/contacts', requireAuth, conversationController.searchContacts);

/**
 * @openapi
 * /conversations/{id}:
 *   get:
 *     summary: Get a single conversation
 *     description: Caller must be an active member.
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: The conversation.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { conversation: { $ref: '#/components/schemas/Conversation' } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { description: 'Not found, or the caller is not a member.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *   put:
 *     summary: Update a group's name, visibility, or image
 *     description: GROUP only. Only OWNER/ADMIN members may update it.
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               name: { type: string }
 *               visibility: { type: string, enum: [PRIVATE, PUBLIC] }
 *               image: { type: string, format: binary }
 *     responses:
 *       200:
 *         description: The updated conversation.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { conversation: { $ref: '#/components/schemas/Conversation' } } }
 *       400: { description: 'Not a GROUP conversation, or invalid input.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
conversationsRouter.get('/:id', requireAuth, conversationController.getConversation);
conversationsRouter.put(
  '/:id',
  requireAuth,
  uploadProfileImage.single('image'),
  validate(updateConversationSchema),
  conversationController.updateConversation,
);

/**
 * @openapi
 * /conversations/{id}/members:
 *   post:
 *     summary: Add members to a group
 *     description: GROUP only, OWNER/ADMIN only. Silently skips ids that don't exist, are already active members, or are blocked by the caller. Max 200 members per group.
 *     tags: [Conversations]
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
 *             required: [memberIds]
 *             properties: { memberIds: { type: array, items: { type: string } } }
 *     responses:
 *       200:
 *         description: The updated conversation.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { conversation: { $ref: '#/components/schemas/Conversation' } } }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
conversationsRouter.post('/:id/members', requireAuth, validate(addMembersSchema), conversationController.addMembers);

/**
 * @openapi
 * /conversations/{id}/members/{userId}:
 *   delete:
 *     summary: Remove a member from a group
 *     description: GROUP only, OWNER/ADMIN only. If the departing member was OWNER, ownership passes to the longest-tenured ADMIN (or MEMBER if none). Idempotent.
 *     tags: [Conversations]
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
conversationsRouter.delete('/:id/members/:userId', requireAuth, conversationController.removeMember);

/**
 * @openapi
 * /conversations/{id}/leave:
 *   post:
 *     summary: Leave a group
 *     description: GROUP only. If the caller was OWNER, ownership passes to the longest-tenured ADMIN (or MEMBER if none).
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       204: { description: 'Left.' }
 *       400: { description: 'Not a GROUP conversation.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
conversationsRouter.post('/:id/leave', requireAuth, conversationController.leaveConversation);

// Self-service join for group search results: PUBLIC groups join
// immediately, PRIVATE groups create a pending request instead.

/**
 * @openapi
 * /conversations/{id}/join:
 *   post:
 *     summary: Join a group found via /conversations/groups/search
 *     description: PUBLIC groups add the caller immediately. PRIVATE groups create a pending join request instead, for an OWNER/ADMIN to accept or reject.
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Joined a PUBLIC group immediately.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status: { type: string, enum: [JOINED] }
 *                 conversation: { $ref: '#/components/schemas/Conversation' }
 *       202:
 *         description: A join request was created for a PRIVATE group.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { status: { type: string, enum: [REQUESTED] } } }
 *       400: { description: 'Already a member, or already have a pending request.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { $ref: '#/components/responses/NotFound' }
 *   delete:
 *     summary: Cancel a pending join request
 *     description: Idempotent.
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       204: { description: 'Cancelled.' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 */
conversationsRouter.post('/:id/join', requireAuth, conversationController.joinGroup);
conversationsRouter.delete('/:id/join', requireAuth, conversationController.cancelJoinRequest);

/**
 * @openapi
 * /conversations/{id}/join-requests:
 *   get:
 *     summary: List pending join requests for a group
 *     description: GROUP only, OWNER/ADMIN only.
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Pending requests, oldest first.
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
 *                       id: { type: string }
 *                       user: { $ref: '#/components/schemas/SafeUser' }
 *                       createdAt: { type: string, format: date-time }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 */
conversationsRouter.get('/:id/join-requests', requireAuth, conversationController.listJoinRequests);

/**
 * @openapi
 * /conversations/{id}/join-requests/{requestId}:
 *   post:
 *     summary: Accept or reject a pending join request
 *     description: GROUP only, OWNER/ADMIN only.
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - in: path
 *         name: requestId
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema: { type: object, required: [accept], properties: { accept: { type: boolean } } }
 *     responses:
 *       204: { description: 'Request accepted or rejected.' }
 *       400: { description: 'Group is already at its member limit.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { $ref: '#/components/responses/Forbidden' }
 *       404: { $ref: '#/components/responses/NotFound' }
 */
conversationsRouter.post(
  '/:id/join-requests/:requestId',
  requireAuth,
  validate(respondJoinRequestSchema),
  conversationController.respondToJoinRequest,
);

/**
 * @openapi
 * /conversations/{id}/upload-auth:
 *   post:
 *     summary: Get a signed Cloudinary upload authorization for a chat attachment
 *     description: >
 *       The client uploads the attachment directly to Cloudinary using this signed payload
 *       (never through this server), then calls POST /conversations/{id}/messages with the
 *       resulting fileUrl. Requires the same membership/block gate as sending a message —
 *       a blocked or non-member caller can't obtain a signature at all.
 *     tags: [Conversations]
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
 *             required: [type]
 *             properties:
 *               type: { type: string, enum: [IMAGE, VIDEO, VOICE_NOTE] }
 *     responses:
 *       200:
 *         description: A signed upload payload for Cloudinary's direct upload API.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 cloudName: { type: string }
 *                 apiKey: { type: string }
 *                 timestamp: { type: integer }
 *                 signature: { type: string }
 *                 folder: { type: string }
 *                 allowedFormats: { type: string }
 *                 resourceType: { type: string, enum: [image, video] }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { description: 'Blocked either direction (DIRECT only).', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *       404: { description: 'Not found, or the caller is not a member.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 */
conversationsRouter.post(
  '/:id/upload-auth',
  requireAuth,
  validate(uploadAuthSchema),
  conversationController.getUploadAuth,
);

/**
 * @openapi
 * /conversations/{id}/messages:
 *   get:
 *     summary: List a conversation's messages
 *     description: Caller must be an active member.
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of messages, newest first.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items: { type: array, items: { $ref: '#/components/schemas/MessageWithViewerState' } }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { description: 'Not found, or the caller is not a member.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *   post:
 *     summary: Send a message
 *     description: >
 *       Plain JSON — any attachment must already be uploaded to Cloudinary via
 *       POST /conversations/{id}/upload-auth before calling this. type defaults to TEXT (or
 *       FILE if fileUrl is set); content is required for TEXT, a fileUrl for every other
 *       type, and durationSeconds for VOICE_NOTE.
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               type: { type: string, enum: [TEXT, IMAGE, VIDEO, FILE, VOICE_NOTE] }
 *               content: { type: string, description: 'Max 4000 characters.' }
 *               replyToId: { type: string }
 *               mentionedUserIds: { type: array, items: { type: string } }
 *               durationSeconds: { type: integer, description: 'Required, positive integer, for VOICE_NOTE.' }
 *               fileUrl: { type: string, description: 'Must be a Cloudinary URL for this account, from /upload-auth.' }
 *               fileName: { type: string }
 *               fileSize: { type: integer }
 *               fileResourceType: { type: string, enum: [image, video] }
 *               fileFormat: { type: string }
 *     responses:
 *       201:
 *         description: The sent message.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { message: { $ref: '#/components/schemas/Message' } } }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       403: { description: 'Blocked either direction (DIRECT only).', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 *       404: { description: 'Not found, or the caller is not a member.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 */
conversationsRouter.get('/:id/messages', requireAuth, conversationController.listMessages);
conversationsRouter.post(
  '/:id/messages',
  requireAuth,
  validate(sendMessageSchema, { withFile: checkSendMessageAttachment }),
  conversationController.sendMessage,
);

/**
 * @openapi
 * /conversations/{id}/read:
 *   post:
 *     summary: Mark messages read up to a given message
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema: { type: object, required: [upToMessageId], properties: { upToMessageId: { type: string } } }
 *     responses:
 *       200:
 *         description: How many previously-unread messages were just marked read.
 *         content:
 *           application/json:
 *             schema: { type: object, properties: { count: { type: integer } } }
 *       400: { $ref: '#/components/responses/BadRequest' }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { description: 'Conversation or message not found.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 */
conversationsRouter.post('/:id/read', requireAuth, validate(markReadSchema), conversationController.markRead);

/**
 * @openapi
 * /conversations/{id}/pins:
 *   get:
 *     summary: List a conversation's pinned messages
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Pinned messages, most recently pinned first.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 pins: { type: array, items: { $ref: '#/components/schemas/PinnedMessage' } }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { description: 'Not found, or the caller is not a member.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 */
conversationsRouter.get('/:id/pins', requireAuth, conversationController.listPinned);

/**
 * @openapi
 * /conversations/{id}/calls:
 *   get:
 *     summary: List a conversation's call history
 *     tags: [Conversations]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *       - $ref: '#/components/parameters/cursorParam'
 *       - $ref: '#/components/parameters/limitParam'
 *     responses:
 *       200:
 *         description: A page of calls, most recent first.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 items: { type: array, items: { $ref: '#/components/schemas/Call' } }
 *                 nextCursor: { type: string, nullable: true }
 *       401: { $ref: '#/components/responses/Unauthorized' }
 *       404: { description: 'Not found, or the caller is not a member.', content: { application/json: { schema: { $ref: '#/components/schemas/Error' } } } }
 */
conversationsRouter.get('/:id/calls', requireAuth, conversationController.listCalls);
