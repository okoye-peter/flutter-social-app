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

/// Mirrors the backend's `MessageType` enum (see prisma/schema.prisma).
/// [system] is never client-submitted — the backend only ever creates it
/// internally for membership events (e.g. "X joined the group").
enum MessageType {
  text,
  image,
  video,
  file,
  voiceNote,
  system;

  /// Converts to the uppercase string the backend sends/expects.
  String toJson() => switch (this) {
    MessageType.voiceNote => 'VOICE_NOTE',
    _ => name.toUpperCase(),
  };

  /// Parses the backend's uppercase `MessageType` string, defaulting to
  /// [text] for anything unrecognized — matching the backend's own
  /// `@default(TEXT)`.
  static MessageType fromJson(String? raw) => switch (raw?.toUpperCase()) {
    'IMAGE' => MessageType.image,
    'VIDEO' => MessageType.video,
    'FILE' => MessageType.file,
    'VOICE_NOTE' => MessageType.voiceNote,
    'SYSTEM' => MessageType.system,
    _ => MessageType.text,
  };
}

enum ConversationVisibility {
  private, public;

  String toJson() => name.toUpperCase();

  static ConversationVisibility fromJson(String? raw) => switch (raw?.toUpperCase()) {
    'PUBLIC' => ConversationVisibility.public,
    _ => ConversationVisibility.private,
  };
}

/// Mirrors the backend's `CallType` enum (see prisma/schema.prisma).
enum CallType {
  voice, video;

  String toJson() => name.toUpperCase();

  static CallType fromJson(String? raw) => switch (raw?.toUpperCase()) {
    'VIDEO' => CallType.video,
    _ => CallType.voice,
  };
}

enum ConversationType {
  direct, group;

  String toJson() => name.toUpperCase();

  static ConversationType fromJson(String? raw) => switch (raw?.toUpperCase()) {
    'GROUP' => ConversationType.group,
    _ => ConversationType.direct,
  };
}

/// Mirrors the backend's `MemberRole` enum (see prisma/schema.prisma) on
/// `ConversationMember` — gates admin actions like removing/promoting a
/// member in a group conversation.
enum MemberRole {
  owner,
  admin,
  member;

  String toJson() => name.toUpperCase();

  static MemberRole fromJson(String? raw) => switch (raw?.toUpperCase()) {
    'OWNER' => MemberRole.owner,
    'ADMIN' => MemberRole.admin,
    _ => MemberRole.member,
  };
}



enum GroupJoinStatus {
  member,
  pending,
  none;

  static GroupJoinStatus fromJson(String? value) {
    switch (value) {
      case 'MEMBER':
        return GroupJoinStatus.member;
      case 'PENDING':
        return GroupJoinStatus.pending;
      default:
        return GroupJoinStatus.none;
    }
  }
}