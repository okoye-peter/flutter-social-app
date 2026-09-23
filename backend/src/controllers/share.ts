import type { Request, Response } from 'express';
import { escapeHtml } from '../lib/html.js';
import { HttpError } from '../lib/http-error.js';
import * as postService from '../services/post.js';

const MAX_DESCRIPTION_LENGTH = 200;

function truncate(text: string, maxLength: number): string {
  return text.length > maxLength ? `${text.slice(0, maxLength - 1).trimEnd()}…` : text;
}

function notFoundPage(): string {
  return '<!doctype html><html><head><meta charset="utf-8"><title>Post not found</title></head>' +
    '<body>This post is no longer available.</body></html>';
}

// Public, unauthenticated page for a single post — its only job is to
// carry Open Graph/Twitter Card meta tags so apps like WhatsApp/Twitter
// can render a rich preview for a shared link. Not part of /api, and
// deliberately has no viewer-specific data (likes, auth, etc).
export async function getPostSharePage(req: Request, res: Response) {
  const postId = req.params.id as string;
  const appUrl = (process.env.APP_URL ?? '').replace(/\/+$/, '');

  let post;
  try {
    post = await postService.getPostPreview(postId);
  } catch (e) {
    if (e instanceof HttpError && e.statusCode === 404) {
      res.status(404).type('html').send(notFoundPage());
      return;
    }
    throw e;
  }

  const title = escapeHtml(`${post.user.name} (@${post.user.username}) on Social App`);
  const description = escapeHtml(
    post.caption.trim() ? truncate(post.caption.trim(), MAX_DESCRIPTION_LENGTH) : 'Shared via Social App',
  );
  const pageUrl = escapeHtml(`${appUrl}/share/posts/${postId}`);
  const image =
    post.mediaType === 'IMAGE' ? post.mediaUrl : post.mediaType === 'VIDEO' ? post.thumbnailUrl : null;

  const imageTags = image
    ? `<meta property="og:image" content="${escapeHtml(image)}">` +
      `<meta name="twitter:card" content="summary_large_image">`
    : `<meta name="twitter:card" content="summary">`;

  const html =
    '<!doctype html><html><head>' +
    '<meta charset="utf-8">' +
    `<title>${title}</title>` +
    `<meta property="og:type" content="website">` +
    `<meta property="og:title" content="${title}">` +
    `<meta property="og:description" content="${description}">` +
    `<meta property="og:url" content="${pageUrl}">` +
    `<meta name="twitter:title" content="${title}">` +
    `<meta name="twitter:description" content="${description}">` +
    imageTags +
    '</head>' +
    `<body>${description}</body></html>`;

  res.type('html').send(html);
}
