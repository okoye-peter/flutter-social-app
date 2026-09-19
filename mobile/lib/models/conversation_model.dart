import 'package:equatable/equatable.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/models/conversation_member_model.dart';
import 'package:social_app/models/user_model.dart';

class ConversationModel extends Equatable {
  final String id;
  final ConversationVisibility? visibility;
  final ConversationType type;
  final String? name;
  final String? image; // URL of the group image
  final String? createdById;
  final DateTime createdAt;
  final List<ConversationMemberModel> members;
  final UserModel? createdBy;

  const ConversationModel({
    required this.id,
    required this.type,
    required this.createdAt,
    this.visibility,
    this.name,
    this.createdById,
    this.createdBy,
    this.image,
    this.members = const [],
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'],
      name: json['name'],
      image: json['image'],
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => ConversationMemberModel.fromJson(m))
              .toList() ??
          const [],
      visibility: json['visibility'] != null
          ? ConversationVisibility.fromJson(json['visibility'])
          : null,
      type: ConversationType.fromJson(json['type']),
      createdById: json['createdById'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      createdBy: json['createdBy'] != null ? UserModel.fromJson(json['createdBy']) : null
    );
  }

  @override
  List<Object?> get props => [id, name, image, visibility, type, members];
}
