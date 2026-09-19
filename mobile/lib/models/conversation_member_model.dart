import 'package:equatable/equatable.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/models/user_model.dart';

class ConversationMemberModel extends Equatable {
  final String id;
  final String conversationId;
  final String userId;
  final UserModel user;
  final MemberRole role;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final DateTime? lastReadAt;

  const ConversationMemberModel({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.user,
    required this.role,
    required this.joinedAt,
    this.leftAt,
    this.lastReadAt,
  });

  factory ConversationMemberModel.fromJson(Map<String, dynamic> json) {
    return ConversationMemberModel(
      id: json['id'],
      conversationId: json['conversationId'],
      userId: json['userId'],
      user: UserModel.fromJson(json['user']),
      role: MemberRole.fromJson(json['role']),
      joinedAt: DateTime.parse(json['joinedAt']),
      leftAt: json['leftAt'] != null ? DateTime.parse(json['leftAt']) : null,
      lastReadAt: json['lastReadAt'] != null ? DateTime.parse(json['lastReadAt']) : null,
    );
  }

  @override
  List<Object?> get props => [id, conversationId, userId, user, role, joinedAt, leftAt, lastReadAt];
}
