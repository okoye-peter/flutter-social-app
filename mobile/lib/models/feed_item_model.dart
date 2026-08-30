import 'package:equatable/equatable.dart';
import 'package:social_app/models/post_model.dart';
import 'package:social_app/models/user_model.dart';

/// The repost activity wrapping a [FeedItemModel.post], when that feed
/// entry exists because someone reposted it rather than authored it.
class RepostInfo extends Equatable {
  const RepostInfo({
    required this.id,
    required this.comment,
    required this.createdAt,
    required this.repostedBy,
  });

  final String id;
  final String? comment;
  final DateTime createdAt;
  final UserModel repostedBy;

  factory RepostInfo.fromJson(Map<String, dynamic> json) {
    return RepostInfo(
      id: json['id'] ?? '',
      comment: json['comment'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      repostedBy: UserModel.fromJson(json['repostedBy'] ?? {}),
    );
  }

  @override
  List<Object?> get props => [id, comment, createdAt, repostedBy];
}

/// One entry in the home feed — matching `GET /posts`'s `items[]`, where
/// [repost] is null for an original post and non-null for a repost
/// (with [RepostInfo.comment] set only for a quote-repost).
class FeedItemModel extends Equatable {
  const FeedItemModel({required this.post, this.repost});

  final PostModel post;
  final RepostInfo? repost;

  bool get isRepost => repost != null;

  factory FeedItemModel.fromJson(Map<String, dynamic> json) {
    return FeedItemModel(
      post: PostModel.fromJson(json['post'] as Map<String, dynamic>),
      repost: json['repost'] != null
          ? RepostInfo.fromJson(json['repost'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Swaps in a fresher [post] (e.g. after a like/bookmark toggle) while
  /// keeping this entry's repost wrapper untouched.
  FeedItemModel copyWithPost(PostModel post) =>
      FeedItemModel(post: post, repost: repost);

  @override
  List<Object?> get props => [post, repost];
}
