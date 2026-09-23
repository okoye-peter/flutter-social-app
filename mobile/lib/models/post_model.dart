import 'package:equatable/equatable.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/models/sound_model.dart';
import 'package:social_app/models/user_model.dart';

PostKind _postKindFromJson(String? raw) {
  return raw?.toUpperCase() == 'REEL' ? PostKind.reel : PostKind.post;
}

String _postKindToJson(PostKind kind) => kind.name.toUpperCase();

class PostModel extends Equatable {
  final String id;
  final String userId;
  final PostKind kind;
  final MediaType mediaType;
  final int commentsCount;
  final int likesCount;
  final int repostsCount;
  final int bookmarksCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? caption;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? soundId;
  final UserModel? user;
  final SoundModel? sound;
  final bool likedByMe;
  final bool bookmarkedByMe;
  final bool repostedByMe;

  const PostModel({
    required this.id,
    required this.userId,
    required this.kind,
    required this.mediaType,
    required this.createdAt,
    required this.updatedAt,
    required this.likedByMe,
    required this.bookmarkedByMe,
    required this.repostedByMe,
    this.commentsCount = 0,
    this.likesCount = 0,
    this.repostsCount = 0,
    this.bookmarksCount = 0,
    this.caption,
    this.mediaUrl,
    this.thumbnailUrl,
    this.soundId,
    this.user,
    this.sound,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'kind': _postKindToJson(kind),
      'mediaType': mediaType.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'commentsCount': commentsCount,
      'likesCount': likesCount,
      'repostsCount': repostsCount,
      'bookmarksCount': bookmarksCount,
      'caption': caption,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'soundId': soundId,
      'user': user?.toJson(),
      'sound': sound?.toJson(),
      'likedByMe': likedByMe,
      'bookmarkedByMe': bookmarkedByMe,
      'repostedByMe': repostedByMe
    };
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'],
      userId: json['userId'],
      kind: _postKindFromJson(json['kind'] as String?),
      mediaType: MediaType.fromJson(json['mediaType'] as String?),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      commentsCount: json['commentsCount'] ?? 0,
      likesCount: json['likesCount'] ?? 0,
      repostsCount: json['repostsCount'] ?? 0,
      bookmarksCount: json['bookmarksCount'] ?? 0,
      caption: json['caption'],
      mediaUrl: json['mediaUrl'],
      thumbnailUrl: json['thumbnailUrl'],
      soundId: json['soundId'],
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      sound: json['sound'] != null ? SoundModel.fromJson(json['sound']) : null,
      // The create-post endpoint returns the raw post row without these
      // (they're computed only by endpoints with a viewer to compute
      // them against) — false is always correct for a freshly created
      // post anyway, since you can't have already liked/bookmarked/
      // reposted something you just created.
      likedByMe: json['likedByMe'] as bool? ?? false,
      bookmarkedByMe: json['bookmarkedByMe'] as bool? ?? false,
      repostedByMe: json['repostedByMe'] as bool? ?? false,
    );
  }

  PostModel copyWith({
    String? id,
    String? userId,
    PostKind? kind,
    MediaType? mediaType,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? commentsCount,
    int? likesCount,
    int? repostsCount,
    int? bookmarksCount,
    String? caption,
    String? mediaUrl,
    String? thumbnailUrl,
    String? soundId,
    UserModel? user,
    SoundModel? sound,
    bool? likedByMe,
    bool? bookmarkedByMe,
    bool? repostedByMe,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      kind: kind ?? this.kind,
      mediaType: mediaType ?? this.mediaType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      commentsCount: commentsCount ?? this.commentsCount,
      likesCount: likesCount ?? this.likesCount,
      repostsCount: repostsCount ?? this.repostsCount,
      bookmarksCount: bookmarksCount ?? this.bookmarksCount,
      caption: caption ?? this.caption,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      soundId: soundId ?? this.soundId,
      user: user ?? this.user,
      sound: sound ?? this.sound,
      likedByMe: likedByMe ?? this.likedByMe,
      bookmarkedByMe: bookmarkedByMe ?? this.bookmarkedByMe,
      repostedByMe: repostedByMe ?? this.repostedByMe,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    kind,
    mediaType,
    createdAt,
    updatedAt,
    commentsCount,
    likesCount,
    repostsCount,
    bookmarksCount,
    caption,
    mediaUrl,
    thumbnailUrl,
    soundId,
    user,
    sound,
    likedByMe,
    bookmarkedByMe,
    repostedByMe
  ];
}
