import { HttpError } from './http-error.js';

export interface CursorPage<T> {
  items: T[];
  nextCursor: string | null;
}

export const DEFAULT_PAGE_SIZE = 20;
export const MAX_PAGE_SIZE = 50;

export function parseLimit(raw: string | undefined): number {
  const limit = Number(raw ?? DEFAULT_PAGE_SIZE);
  if (!Number.isInteger(limit) || limit < 1 || limit > MAX_PAGE_SIZE) {
    throw new HttpError(400, `limit must be an integer between 1 and ${MAX_PAGE_SIZE}`);
  }
  return limit;
}

export function encodeCursor(createdAt: Date, id: string): string {
  return Buffer.from(`${createdAt.toISOString()}_${id}`, 'utf8').toString('base64url');
}

export function decodeCursor(raw: string | undefined): { createdAt: Date; id: string } | undefined {
  if (!raw) return undefined;
  const [iso, id] = Buffer.from(raw, 'base64url').toString('utf8').split('_');
  if (!iso || !id || Number.isNaN(new Date(iso).getTime())) {
    throw new HttpError(400, 'Invalid cursor');
  }
  return { createdAt: new Date(iso), id };
}

export function buildCursorWhere(cursor?: { createdAt: Date; id: string }) {
  if (!cursor) return {};
  return {
    OR: [{ createdAt: { lt: cursor.createdAt } }, { createdAt: cursor.createdAt, id: { lt: cursor.id } }],
  };
}

export function toPage<T extends { createdAt: Date; id: string }>(rows: T[], limit: number): CursorPage<T> {
  const hasMore = rows.length > limit;
  const items = hasMore ? rows.slice(0, limit) : rows;
  const last = items.at(-1);
  return { items, nextCursor: hasMore && last ? encodeCursor(last.createdAt, last.id) : null };
}
