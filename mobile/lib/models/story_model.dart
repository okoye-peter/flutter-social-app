import 'package:equatable/equatable.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/models/user_model.dart';

/// One story item, matching the backend's `Story` shape from
/// `GET /api/stories` (see backend/src/services/story.ts).
class StoryModel extends Equatable {
  const StoryModel({
    required this.id,
    required this.mediaType,
    required this.mediaUrl,
    required this.caption,
    required this.createdAt,
    required this.seenByMe,
  });

  final String id;
  final MediaType mediaType;
  final String mediaUrl;
  final String caption;
  final DateTime createdAt;
  final bool seenByMe;

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'] ?? '',
      mediaType: MediaType.fromJson(json['mediaType'] as String?),
      mediaUrl: json['mediaUrl'] ?? '',
      caption: json['caption'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      seenByMe: json['seenByMe'] ?? false,
    );
  }

  StoryModel copyWith({bool? seenByMe}) {
    return StoryModel(
      id: id,
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      caption: caption,
      createdAt: createdAt,
      seenByMe: seenByMe ?? this.seenByMe,
    );
  }

  @override
  List<Object?> get props => [id, mediaType, mediaUrl, caption, createdAt, seenByMe];
}

/// One author's set of active stories, matching a `groups[]` entry from
/// `GET /api/stories`.
class StoryGroupModel extends Equatable {
  const StoryGroupModel({
    required this.user,
    required this.stories,
    required this.hasUnseen,
  });

  final UserModel user;
  final List<StoryModel> stories;
  final bool hasUnseen;

  factory StoryGroupModel.fromJson(Map<String, dynamic> json) {
    return StoryGroupModel(
      user: UserModel.fromJson(json['user'] ?? {}),
      stories: (json['stories'] as List<dynamic>? ?? [])
          .map((s) => StoryModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      hasUnseen: json['hasUnseen'] ?? false,
    );
  }

  /// Returns a copy of this group with [storyId] marked as seen and
  /// [hasUnseen] recomputed from the updated stories.
  StoryGroupModel withStorySeen(String storyId) {
    final updatedStories = [
      for (final story in stories)
        story.id == storyId ? story.copyWith(seenByMe: true) : story,
    ];
    return StoryGroupModel(
      user: user,
      stories: updatedStories,
      hasUnseen: updatedStories.any((story) => !story.seenByMe),
    );
  }

  @override
  List<Object?> get props => [user, stories, hasUnseen];
}
