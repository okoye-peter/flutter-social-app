import 'package:equatable/equatable.dart';
import 'package:social_app/models/user_model.dart';

class CommentModel extends Equatable {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final int likesCount;
  final String? replyToId;
  final DateTime createdAt;
  final UserModel? user;
  final bool likedByMe;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.likesCount,
    required this.createdAt,
    this.replyToId,
    this.user,
    this.likedByMe = false,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'],
      postId: json['postId'],
      userId: json['userId'],
      content: json['content'],
      likesCount: json['likesCount'],
      createdAt: DateTime.parse(json['createdAt']),
      replyToId: json['replyToId'],
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      // Only listComments/listReplies compute this server-side; a
      // freshly created/updated comment can't have been liked yet.
      likedByMe: json['likedByMe'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'content': content,
      'likesCount': likesCount,
      'createdAt': createdAt.toIso8601String(),
      'replyToId': replyToId,
      'likedByMe': likedByMe,
    };
  }

  CommentModel copyWith({
    String? id,
    String? postId,
    String? userId,
    String? content,
    int? likesCount,
    String? replyToId,
    DateTime? createdAt,
    UserModel? user,
    bool? likedByMe,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      likesCount: likesCount ?? this.likesCount,
      replyToId: replyToId ?? this.replyToId,
      createdAt: createdAt ?? this.createdAt,
      user: user ?? this.user,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }

  @override
  List<Object?> get props => [
    id,
    postId,
    userId,
    content,
    likesCount,
    replyToId,
    createdAt,
    user,
    likedByMe,
  ];
}
