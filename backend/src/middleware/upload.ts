import multer from 'multer';
import { HttpError } from '../lib/http-error.js';

const MAX_UPLOAD_SIZE_BYTES = Number(process.env.MAX_UPLOAD_SIZE_MB ?? 7.5) * 1024 * 1024;

export const uploadProfileImage = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_UPLOAD_SIZE_BYTES },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith('image/')) {
      return cb(new HttpError(400, 'Only image uploads are allowed'));
    }
    cb(null, true);
  },
});

const MAX_POST_MEDIA_SIZE_BYTES = Number(process.env.MAX_POST_MEDIA_SIZE_MB ?? 100) * 1024 * 1024;
const ALLOWED_POST_MEDIA_TYPES = ['image/', 'video/'];

// Posts/reels can carry a much larger video than a profile photo, so this
// gets its own size ceiling instead of sharing MAX_UPLOAD_SIZE_MB.
export const uploadPostMedia = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_POST_MEDIA_SIZE_BYTES },
  fileFilter: (_req, file, cb) => {
    const isAllowed = ALLOWED_POST_MEDIA_TYPES.some((prefix) => file.mimetype.startsWith(prefix));
    if (!isAllowed) {
      return cb(new HttpError(400, 'Only image or video uploads are allowed'));
    }
    cb(null, true);
  },
});

const MAX_STORY_MEDIA_SIZE_BYTES = Number(process.env.MAX_STORY_MEDIA_SIZE_MB ?? 50) * 1024 * 1024;

export const uploadStoryMedia = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_STORY_MEDIA_SIZE_BYTES },
  fileFilter: (_req, file, cb) => {
    const isAllowed = ALLOWED_POST_MEDIA_TYPES.some((prefix) => file.mimetype.startsWith(prefix));
    if (!isAllowed) {
      return cb(new HttpError(400, 'Only image or video uploads are allowed'));
    }
    cb(null, true);
  },
});

const MAX_CHAT_ATTACHMENT_SIZE_BYTES = Number(process.env.MAX_CHAT_ATTACHMENT_SIZE_MB ?? 9) * 1024 * 1024;
const ALLOWED_CHAT_ATTACHMENT_TYPES = ['image/', 'video/', 'application/pdf', 'audio/'];

// Chat files (including voice notes, hence 'audio/') get their own, larger
// ceiling than a profile photo — product requirement is 9MB.
export const uploadChatAttachment = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_CHAT_ATTACHMENT_SIZE_BYTES },
  fileFilter: (_req, file, cb) => {
    const isAllowed = ALLOWED_CHAT_ATTACHMENT_TYPES.some((prefix) => file.mimetype.startsWith(prefix));
    if (!isAllowed) {
      return cb(new HttpError(400, 'Only image, video, audio, or PDF uploads are allowed'));
    }
    cb(null, true);
  },
});
