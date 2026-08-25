// Central home for enums shared across the app, so the same set of
// cases isn't redeclared per screen/widget.

/// Severity styling for `AppToast`.
enum ToastKind { success, error, warning, info }

/// Mirrors the backend's single `MediaType` enum (see
/// prisma/schema.prisma), shared by `Post` and `Story` alike — so this one
/// enum covers stories, posts, and reels. A story never actually persists
/// as `text` (its media is mandatory), but the type still allows it since
/// that's exactly how the backend models it too.
enum MediaType {
  text,
  image,
  video;

  /// Converts to the uppercase string the backend sends/expects.
  String toJson() => name.toUpperCase();

  /// Parses the backend's uppercase `MediaType` string, defaulting to
  /// [text] for anything unrecognized — matching the backend's own
  /// `@default(TEXT)`.
  static MediaType fromJson(String? raw) => switch (raw?.toUpperCase()) {
    'IMAGE' => MediaType.image,
    'VIDEO' => MediaType.video,
    _ => MediaType.text,
  };
}

/// UI-only "what's currently attached" state for an in-progress
/// story/post composer, shared by `CreateStoryScreen` and
/// `CreateFeedScreen`. `none` means nothing picked yet — it's never
/// persisted, unlike [MediaType].
enum ComposeMediaType { none, image, video }

/// Where a `ReelsTile` is being shown — controls what tap/double-tap do,
/// since the two contexts want different gestures for the same area:
/// - [feed]: tap opens the reel's details page, double-tap mutes.
/// - [details]: tap toggles play/pause, double-tap toggles like.
enum ReelInteractionMode { feed, details }

/// Which tab of media a profile screen grid is showing.
enum ProfileMediaType { post, reel, repost, mention }

/// Mirrors the backend's `PostKind` enum (Prisma) — orthogonal to
/// [MediaType]: a video reel is `PostKind.reel` + `MediaType.video`, never
/// a `PostKind.video`.
enum PostKind { post, reel }
