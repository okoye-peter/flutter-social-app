import path from 'node:path';
import { fileURLToPath } from 'node:url';
import swaggerJsdoc from 'swagger-jsdoc';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Dev runs this file straight from src/*.ts (tsx); prod runs the compiled
// dist/*.js — match whichever extension this module itself was loaded as so
// the route glob below finds the right files in both cases.
const routeExt = path.extname(fileURLToPath(import.meta.url));

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.0.3',
    info: {
      title: 'Social App API',
      version: '1.0.0',
      description: 'REST API for the social app backend: auth, profiles, posts, stories, sounds, chats, and notifications.',
    },
    servers: [{ url: '/api' }],
    security: [{ bearerAuth: [] }],
    tags: [
      { name: 'Auth', description: 'Registration, login, tokens, OTP verification, password reset' },
      { name: 'Users', description: 'Profiles, follow graph, blocking, search' },
      { name: 'Posts', description: 'Feed posts and reels, likes, bookmarks, reposts, tags' },
      { name: 'Comments', description: 'Post comments and replies' },
      { name: 'Stories', description: '24-hour disappearing stories' },
      { name: 'Sounds', description: 'Audio extracted from video posts, reusable on new posts' },
      { name: 'Conversations', description: 'Direct and group chats' },
      { name: 'Messages', description: 'Actions on an individual message: delete, react, pin' },
      { name: 'Notifications', description: 'In-app notifications and push device tokens' },
      { name: 'Reports', description: 'Reporting posts, comments, or users' },
    ],
    components: {
      securitySchemes: {
        bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      },
      schemas: {
        Error: {
          type: 'object',
          properties: { error: { type: 'string' } },
        },
        TokenPair: {
          type: 'object',
          properties: {
            accessToken: { type: 'string' },
            refreshToken: { type: 'string' },
          },
        },
        SafeUser: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            name: { type: 'string' },
            username: { type: 'string' },
            email: { type: 'string' },
            phoneNumber: { type: 'string' },
            image: { type: 'string' },
            aboutMe: { type: 'string' },
            isOnline: { type: 'boolean' },
            fcmToken: { type: 'string', nullable: true },
            lastSeen: { type: 'string', format: 'date-time' },
            followersCount: { type: 'integer' },
            followingCount: { type: 'integer' },
            postsCount: { type: 'integer' },
            createdAt: { type: 'string', format: 'date-time' },
            updatedAt: { type: 'string', format: 'date-time' },
          },
        },
        PostAuthor: {
          type: 'object',
          description: "A post/comment/story author's public-facing fields — narrower than SafeUser.",
          properties: {
            id: { type: 'string' },
            name: { type: 'string' },
            username: { type: 'string' },
            image: { type: 'string' },
          },
        },
        Post: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            userId: { type: 'string' },
            kind: { type: 'string', enum: ['POST', 'REEL'] },
            mediaType: { type: 'string', enum: ['TEXT', 'IMAGE', 'VIDEO'] },
            caption: { type: 'string' },
            mediaUrl: { type: 'string', nullable: true },
            thumbnailUrl: { type: 'string', nullable: true },
            soundId: { type: 'string', nullable: true },
            commentsCount: { type: 'integer' },
            likesCount: { type: 'integer' },
            repostsCount: { type: 'integer' },
            bookmarksCount: { type: 'integer' },
            createdAt: { type: 'string', format: 'date-time' },
            updatedAt: { type: 'string', format: 'date-time' },
            user: { $ref: '#/components/schemas/PostAuthor' },
            likedByMe: { type: 'boolean' },
            bookmarkedByMe: { type: 'boolean' },
            repostedByMe: { type: 'boolean' },
          },
        },
        Repost: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            postId: { type: 'string' },
            userId: { type: 'string' },
            comment: { type: 'string', nullable: true },
            createdAt: { type: 'string', format: 'date-time' },
          },
        },
        Comment: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            postId: { type: 'string' },
            userId: { type: 'string' },
            content: { type: 'string' },
            likesCount: { type: 'integer' },
            replyToId: { type: 'string', nullable: true },
            replyTo: {
              type: 'object',
              nullable: true,
              description: 'Preview of the replied-to message (on sends and message lists).',
              properties: {
                id: { type: 'string' },
                type: { type: 'string' },
                content: { type: 'string', nullable: true },
                deletedAt: { type: 'string', format: 'date-time', nullable: true },
                sender: { type: 'object', nullable: true, properties: { id: { type: 'string' }, name: { type: 'string' } } },
              },
            },
            createdAt: { type: 'string', format: 'date-time' },
            updatedAt: { type: 'string', format: 'date-time' },
            user: { $ref: '#/components/schemas/PostAuthor' },
            likedByMe: { type: 'boolean' },
          },
        },
        Story: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            userId: { type: 'string' },
            mediaType: { type: 'string', enum: ['IMAGE', 'VIDEO'] },
            mediaUrl: { type: 'string' },
            caption: { type: 'string' },
            createdAt: { type: 'string', format: 'date-time' },
            expiresAt: { type: 'string', format: 'date-time' },
            seenByMe: { type: 'boolean' },
          },
        },
        StoryGroup: {
          type: 'object',
          description: 'All of one author’s active stories, for the stories-feed strip.',
          properties: {
            user: { $ref: '#/components/schemas/PostAuthor' },
            stories: { type: 'array', items: { $ref: '#/components/schemas/Story' } },
            hasUnseen: { type: 'boolean' },
          },
        },
        Sound: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            sourcePostId: { type: 'string' },
            creatorId: { type: 'string' },
            title: { type: 'string' },
            audioUrl: { type: 'string' },
            usageCount: { type: 'integer' },
            createdAt: { type: 'string', format: 'date-time' },
          },
        },
        Notification: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            userId: { type: 'string' },
            actorId: { type: 'string', nullable: true },
            type: {
              type: 'string',
              enum: [
                'FOLLOW', 'POST_LIKE', 'POST_COMMENT', 'COMMENT_LIKE', 'COMMENT_REPLY',
                'REPOST', 'TAG', 'MENTION', 'MESSAGE', 'CALL',
              ],
            },
            postId: { type: 'string', nullable: true },
            commentId: { type: 'string', nullable: true },
            conversationId: { type: 'string', nullable: true },
            messageId: { type: 'string', nullable: true },
            isRead: { type: 'boolean' },
            readAt: { type: 'string', format: 'date-time', nullable: true },
            createdAt: { type: 'string', format: 'date-time' },
          },
        },
        Report: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            reporterId: { type: 'string', nullable: true },
            reportedUserId: { type: 'string', nullable: true },
            postId: { type: 'string', nullable: true },
            commentId: { type: 'string', nullable: true },
            reason: {
              type: 'string',
              enum: ['SPAM', 'HARASSMENT', 'HATE_SPEECH', 'NUDITY', 'VIOLENCE', 'MISINFORMATION', 'OTHER'],
            },
            details: { type: 'string', nullable: true },
            status: { type: 'string', enum: ['PENDING', 'REVIEWED', 'ACTIONED', 'DISMISSED'] },
            createdAt: { type: 'string', format: 'date-time' },
            resolvedAt: { type: 'string', format: 'date-time', nullable: true },
          },
        },
        Message: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            conversationId: { type: 'string' },
            senderId: { type: 'string', nullable: true },
            type: { type: 'string', enum: ['TEXT', 'IMAGE', 'VIDEO', 'FILE', 'VOICE_NOTE', 'SYSTEM'] },
            content: { type: 'string', nullable: true },
            fileUrl: { type: 'string', nullable: true },
            fileName: { type: 'string', nullable: true },
            fileSize: { type: 'integer', nullable: true },
            duration: { type: 'integer', nullable: true },
            replyToId: { type: 'string', nullable: true },
            createdAt: { type: 'string', format: 'date-time' },
            updatedAt: { type: 'string', format: 'date-time' },
            deletedAt: { type: 'string', format: 'date-time', nullable: true },
          },
        },
        MessageWithViewerState: {
          allOf: [
            { $ref: '#/components/schemas/Message' },
            {
              type: 'object',
              properties: {
                sender: { allOf: [{ $ref: '#/components/schemas/SafeUser' }], nullable: true },
                reactions: {
                  type: 'array',
                  description: "Every reaction on the message, one per user.",
                  items: { type: 'object', properties: { emoji: { type: 'string' }, userId: { type: 'string' } } },
                },
                myReaction: { type: 'string', nullable: true },
                readByMe: { type: 'boolean' },
              },
            },
          ],
        },
        ConversationMember: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            conversationId: { type: 'string' },
            userId: { type: 'string' },
            role: { type: 'string', enum: ['OWNER', 'ADMIN', 'MEMBER'] },
            joinedAt: { type: 'string', format: 'date-time' },
            leftAt: { type: 'string', format: 'date-time', nullable: true },
            lastReadAt: { type: 'string', format: 'date-time', nullable: true },
            user: { $ref: '#/components/schemas/SafeUser' },
          },
        },
        Conversation: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            type: { type: 'string', enum: ['DIRECT', 'GROUP'] },
            name: { type: 'string', nullable: true },
            image: { type: 'string', nullable: true },
            visibility: { type: 'string', enum: ['PRIVATE', 'PUBLIC'], nullable: true },
            createdById: { type: 'string', nullable: true },
            lastMessageAt: { type: 'string', format: 'date-time', nullable: true },
            createdAt: { type: 'string', format: 'date-time' },
            updatedAt: { type: 'string', format: 'date-time' },
            members: { type: 'array', items: { $ref: '#/components/schemas/ConversationMember' } },
            createdBy: { allOf: [{ $ref: '#/components/schemas/SafeUser' }], nullable: true },
          },
        },
        PinnedMessage: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            conversationId: { type: 'string' },
            messageId: { type: 'string' },
            pinnedById: { type: 'string', nullable: true },
            pinnedAt: { type: 'string', format: 'date-time' },
            message: { $ref: '#/components/schemas/Message' },
            pinnedBy: { allOf: [{ $ref: '#/components/schemas/SafeUser' }], nullable: true },
          },
        },
        Call: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            conversationId: { type: 'string' },
            initiatorId: { type: 'string', nullable: true },
            type: { type: 'string', enum: ['VOICE', 'VIDEO'] },
            status: { type: 'string', enum: ['RINGING', 'ONGOING', 'ENDED', 'MISSED', 'DECLINED'] },
            startedAt: { type: 'string', format: 'date-time' },
            endedAt: { type: 'string', format: 'date-time', nullable: true },
          },
        },
      },
      responses: {
        Unauthorized: {
          description: 'Missing or invalid bearer token.',
          content: { 'application/json': { schema: { $ref: '#/components/schemas/Error' } } },
        },
        NotFound: {
          description: 'The resource does not exist (or is not visible to the caller).',
          content: { 'application/json': { schema: { $ref: '#/components/schemas/Error' } } },
        },
        BadRequest: {
          description: 'Validation failed.',
          content: { 'application/json': { schema: { $ref: '#/components/schemas/Error' } } },
        },
        Forbidden: {
          description: "The caller isn't allowed to do this.",
          content: { 'application/json': { schema: { $ref: '#/components/schemas/Error' } } },
        },
      },
      parameters: {
        cursorParam: {
          in: 'query',
          name: 'cursor',
          schema: { type: 'string' },
          description: "Opaque pagination cursor from a previous response's nextCursor.",
        },
        limitParam: {
          in: 'query',
          name: 'limit',
          schema: { type: 'integer', minimum: 1, maximum: 50, default: 20 },
        },
      },
    },
  },
  apis: [path.join(__dirname, `routes/*${routeExt}`)],
};

export const swaggerSpec = swaggerJsdoc(options);
