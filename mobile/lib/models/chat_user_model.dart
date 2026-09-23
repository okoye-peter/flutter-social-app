import 'package:equatable/equatable.dart';
import 'package:social_app/models/message_model.dart';
import 'package:social_app/models/user_model.dart';

class ChatUserModel extends Equatable {
  const ChatUserModel({
    required this.user,
    required this.unreadCount,
    required this.conversationId,
    this.lastMessageAt,
    this.lastMessage,
  });

  final UserModel user;
  final String conversationId;
  final int unreadCount;
  // Null when the conversation has never had a message sent in it yet.
  final DateTime? lastMessageAt;
  final MessageModel? lastMessage;

  @override
  List<Object?> get props => [
    user,
    unreadCount,
    conversationId,
    lastMessageAt,
    lastMessage,
  ];

  ChatUserModel copyWith({
    UserModel? user,
    int? unreadCount,
    String? conversationId,
    DateTime? lastMessageAt,
    MessageModel? lastMessage,
  }) {
    return ChatUserModel(
      user: user ?? this.user,
      unreadCount: unreadCount ?? this.unreadCount,
      conversationId: conversationId ?? this.conversationId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }

  factory ChatUserModel.fromJson(Map<String, dynamic> json) {
    return ChatUserModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      unreadCount: json['unreadCount'] as int,
      conversationId: json['conversationId'] as String,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'] as String)
          : null,
      lastMessage: json['lastMessage'] != null
          ? MessageModel.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
    );
  }
}
