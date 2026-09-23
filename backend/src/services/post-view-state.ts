import type { Post } from '../../generated/prisma/index.js';

// Deliberately excludes password/email/phoneNumber/fcmToken — this goes
// out to every viewer of a post, not just the post's own author.
export type PostAuthor = { id: string; name: string; username: string; image: string };

export type PostWithViewerState = Post & {
  user: PostAuthor;
  likedByMe: boolean;
  bookmarkedByMe: boolean;
  repostedByMe: boolean;
};

export const VIEWER_STATE_INCLUDE = (viewerId: string) => ({
  user: { select: { id: true, name: true, username: true, image: true } },
  likes: { where: { userId: viewerId }, select: { id: true } },
  bookmarks: { where: { userId: viewerId }, select: { id: true } },
  reposts: { where: { userId: viewerId }, select: { id: true } },
});

type PostWithRawViewerState = Post & {
  user: PostAuthor;
  likes: { id: string }[];
  bookmarks: { id: string }[];
  reposts: { id: string }[];
};

export function withViewerState(post: PostWithRawViewerState): PostWithViewerState {
  const { likes, bookmarks, reposts, ...rest } = post;
  return {
    ...rest,
    likedByMe: likes.length > 0,
    bookmarkedByMe: bookmarks.length > 0,
    repostedByMe: reposts.length > 0,
  };
}
