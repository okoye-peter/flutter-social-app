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

  const PostModel({
    required this.id,
    required this.userId,
    required this.kind,
    required this.mediaType,
    required this.createdAt,
    required this.updatedAt,
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
  ];
}
