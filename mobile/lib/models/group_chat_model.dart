import 'package:equatable/equatable.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/models/message_model.dart';

/// One row of the "my groups" inbox (GET /conversations/groups) — a group
/// the caller is already a member of. Not a [ConversationModel]: this
/// endpoint returns `conversationId` + summary fields, not the full
/// conversation with its members.
class GroupChatModel extends Equatable {
  const GroupChatModel({
    required this.conversationId,
    required this.name,
    required this.image,
    required this.memberCount,
    required this.unreadCount,
    this.visibility,
    this.lastMessage,
    this.lastMessageAt,
  });

  final String conversationId;
  final String name;
  final String image;
  final ConversationVisibility? visibility;
  final int memberCount;
  final int unreadCount;
  // Null when nothing has been sent in the group yet.
  final MessageModel? lastMessage;
  final DateTime? lastMessageAt;

  factory GroupChatModel.fromJson(Map<String, dynamic> json) {
    return GroupChatModel(
      conversationId: json['conversationId'] as String,
      name: json['name'] as String? ?? '',
      image: json['image'] as String? ?? '',
      visibility: json['visibility'] != null
          ? ConversationVisibility.fromJson(json['visibility'] as String)
          : null,
      memberCount: json['memberCount'] as int? ?? 0,
      unreadCount: json['unreadCount'] as int? ?? 0,
      lastMessage: json['lastMessage'] != null
          ? MessageModel.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'] as String)
          : null,
    );
  }

  GroupChatModel copyWith({
    String? name,
    String? image,
    int? memberCount,
    int? unreadCount,
    MessageModel? lastMessage,
    DateTime? lastMessageAt,
  }) {
    return GroupChatModel(
      conversationId: conversationId,
      name: name ?? this.name,
      image: image ?? this.image,
      visibility: visibility,
      memberCount: memberCount ?? this.memberCount,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  @override
  List<Object?> get props => [
    conversationId,
    name,
    image,
    visibility,
    memberCount,
    unreadCount,
    lastMessage,
    lastMessageAt,
  ];
}
