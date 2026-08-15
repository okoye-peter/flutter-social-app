import multer from 'multer';

const MAX_UPLOAD_SIZE_BYTES = Number(process.env.MAX_UPLOAD_SIZE_MB ?? 7.5) * 1024 * 1024;

export const uploadProfileImage = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_UPLOAD_SIZE_BYTES },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith('image/')) {
      return cb(new Error('Only image uploads are allowed'));
    }
    cb(null, true);
  },
});

const ALLOWED_CHAT_ATTACHMENT_TYPES = ['image/', 'video/', 'application/pdf'];

// Broader than uploadProfileImage: chat messages can carry images, video,
// or PDFs, not just images.
export const uploadChatAttachment = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_UPLOAD_SIZE_BYTES },
  fileFilter: (_req, file, cb) => {
    const isAllowed = ALLOWED_CHAT_ATTACHMENT_TYPES.some((prefix) => file.mimetype.startsWith(prefix));
    if (!isAllowed) {
      return cb(new Error('Only image, video, or PDF uploads are allowed'));
    }
    cb(null, true);
  },
});
