import { prisma } from '../prisma.js';
import { HttpError } from '../lib/http-error.js';
import { isUniqueConstraintError } from '../lib/prisma-errors.js';
import { decodeCursor, buildCursorWhere, toPage, parseLimit, type CursorPage } from '../lib/pagination.js';
import type { Sound } from '../../generated/prisma/index.js';

const MAX_TITLE_LENGTH = 100;

/**
 * Returns the Sound extracted from a video post's own audio, creating
 * it on first use so casual video posts don't carry a Sound row until
 * someone actually wants to reuse the audio.
 */
export async function getOrCreateSoundForPost(postId: string): Promise<Sound> {
  const existing = await prisma.sound.findUnique({ where: { sourcePostId: postId } });
  if (existing) return existing;

  const post = await prisma.post.findUnique({
    where: { id: postId },
    include: { user: { select: { name: true } } },
  });
  if (!post) throw new HttpError(404, 'Post not found');
  if (post.mediaType !== 'VIDEO' || !post.mediaUrl) {
    throw new HttpError(400, 'Only video posts have audio that can be used as a sound');
  }

  const title = post.caption.trim() || `${post.user.name} · original audio`;

  try {
    return await prisma.sound.create({
      data: {
        sourcePostId: post.id,
        creatorId: post.userId,
        title: title.slice(0, MAX_TITLE_LENGTH),
        audioUrl: post.mediaUrl,
      },
    });
  } catch (e) {
    if (isUniqueConstraintError(e)) {
      // Lost a create race against a concurrent call for the same post —
      // sourcePostId is unique, so the winner's row already exists.
      return await prisma.sound.findUniqueOrThrow({ where: { sourcePostId: postId } });
    }
    throw e;
  }
}

export async function getSound(soundId: string): Promise<Sound> {
  const sound = await prisma.sound.findUnique({ where: { id: soundId } });
  if (!sound) throw new HttpError(404, 'Sound not found');
  return sound;
}

export async function listSounds(query: { q?: string; cursor?: string; limit?: string }): Promise<CursorPage<Sound>> {
  const limit = parseLimit(query.limit);
  const cursor = decodeCursor(query.cursor);
  const q = query.q?.trim();

  const rows = await prisma.sound.findMany({
    where: {
      ...(q ? { title: { contains: q, mode: 'insensitive' as const } } : {}),
      ...buildCursorWhere(cursor),
    },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
  });

  return toPage(rows, limit);
}
