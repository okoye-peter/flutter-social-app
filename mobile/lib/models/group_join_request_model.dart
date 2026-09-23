import 'package:equatable/equatable.dart';
import 'package:social_app/models/user_model.dart';

/// A pending request to join a PRIVATE group (GET
/// /conversations/:id/join-requests) — only OWNER/ADMIN members see these.
class GroupJoinRequestModel extends Equatable {
  const GroupJoinRequestModel({
    required this.id,
    required this.user,
    required this.createdAt,
  });

  final String id;
  final UserModel user;
  final DateTime createdAt;

  factory GroupJoinRequestModel.fromJson(Map<String, dynamic> json) {
    return GroupJoinRequestModel(
      id: json['id'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, user, createdAt];
}
