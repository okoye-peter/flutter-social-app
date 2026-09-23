import { v2 as cloudinary, type UploadApiErrorResponse } from 'cloudinary';

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// cloudinary@2.10.0's upload_stream only parses the response body for
// http_code in [200, 400, 401, 404, 420, 500] (lib/uploader.js); 403 isn't in
// that list, so on a 403 the SDK discards the body and reports only this
// generic message — Cloudinary's real reason (in the X-Cld-Error header) never
// reaches us. A 403 here almost always means the API key lacks upload/"create"
// permission (scoped key, or an unverified account) rather than a code bug.
function logCloudinaryError(context: string, error: UploadApiErrorResponse) {
  const hint = error.http_code === 403
    ? ' — likely missing upload ("create") permission on this API key; check Cloudinary Console > Settings > Access Keys, or verify the account email'
    : '';
  console.error(`Cloudinary ${context} failed:`, error.message, hint);
}

// Cloudinary's SDK default timeout (60s) is too tight for larger video/chat
// attachments on a slow uplink, so it aborts with http_code 499 well before
// the file finishes sending. 180s plus one retry covers a transient network
// hiccup without masking a genuinely broken upload.
const UPLOAD_TIMEOUT_MS = 180_000;
const MAX_UPLOAD_ATTEMPTS = 2;

function uploadOnce(buffer: Buffer, folder: string, resourceType: 'image' | 'auto'): Promise<string> {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder, resource_type: resourceType, timeout: UPLOAD_TIMEOUT_MS },
      (error, result) => {
        if (error || !result) {
          return reject(error ?? new Error('Cloudinary upload failed'));
        }
        resolve(result.secure_url);
      },
    );
    stream.end(buffer);
  });
}

async function upload(buffer: Buffer, folder: string, resourceType: 'image' | 'auto'): Promise<string> {
  for (let attempt = 1; attempt <= MAX_UPLOAD_ATTEMPTS; attempt++) {
    try {
      return await uploadOnce(buffer, folder, resourceType);
    } catch (error) {
      const isTimeout = (error as UploadApiErrorResponse)?.http_code === 499;
      const isLastAttempt = attempt === MAX_UPLOAD_ATTEMPTS;
      if (!isTimeout || isLastAttempt) {
        logCloudinaryError('upload', error as UploadApiErrorResponse);
        throw error;
      }
      console.warn(`Cloudinary upload timed out, retrying (attempt ${attempt + 1}/${MAX_UPLOAD_ATTEMPTS})`);
    }
  }
  throw new Error('Cloudinary upload failed');
}

export function uploadImage(buffer: Buffer, folder: string): Promise<string> {
  return upload(buffer, folder, 'image');
}

// For chat attachments, which unlike profile photos aren't always images —
// 'auto' lets Cloudinary route video/PDF/etc. to the right resource type
// instead of us branching on mimetype ourselves.
export function uploadAttachment(buffer: Buffer, folder: string): Promise<string> {
  return upload(buffer, folder, 'auto');
}

export type ChatAttachmentType = 'IMAGE' | 'VIDEO' | 'VOICE_NOTE';

export interface SignedUploadAuth {
  cloudName: string;
  apiKey: string;
  timestamp: number;
  signature: string;
  folder: string;
  allowedFormats: string;
  resourceType: 'image' | 'video';
}

// Cloudinary has no separate 'audio' resource type — voice notes upload
// under 'video' like any other audio/video container; allowedFormats is
// what actually distinguishes a VOICE_NOTE from a VIDEO server-side.
const CHAT_ATTACHMENT_PROFILES: Record<ChatAttachmentType, { resourceType: 'image' | 'video'; formats: string[] }> = {
  IMAGE: { resourceType: 'image', formats: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'gif'] },
  VIDEO: { resourceType: 'video', formats: ['mp4', 'mov', 'webm', 'm4v', '3gp'] },
  VOICE_NOTE: { resourceType: 'video', formats: ['m4a', 'aac', 'mp3', 'wav', 'ogg'] },
};

// Mints a signed direct-upload authorization for a chat attachment, so the
// client can upload straight to Cloudinary instead of proxying bytes
// through our server. Callers MUST run assertCanPostToConversation first —
// this function itself does no authorization, only signing.
export function createChatAttachmentUploadAuth(conversationId: string, type: ChatAttachmentType): SignedUploadAuth {
  const { resourceType, formats } = CHAT_ATTACHMENT_PROFILES[type];
  const config = cloudinary.config();
  const timestamp = Math.floor(Date.now() / 1000);
  const folder = `chat-attachments/${conversationId}`;
  const allowedFormats = formats.join(',');

  const signed = cloudinary.utils.sign_request(
    { timestamp, folder, allowed_formats: allowedFormats },
    { api_key: config.api_key!, api_secret: config.api_secret! },
  );

  return {
    cloudName: config.cloud_name!,
    apiKey: signed.api_key,
    timestamp: signed.timestamp,
    signature: signed.signature,
    folder: signed.folder,
    allowedFormats,
    resourceType,
  };
}
