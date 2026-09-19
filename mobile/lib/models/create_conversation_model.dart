import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:social_app/core/enums/app_enums.dart';

class CreateGroupConversationModel extends Equatable {
  final String name;
  final ConversationVisibility visibility;
  final List<String> memberIds;
  final String image; // URL of the group image

  const CreateGroupConversationModel({
    required this.name,
    required this.visibility,
    required this.memberIds,
    required this.image,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'visibility': visibility.toJson(),
      'memberIds': jsonEncode(memberIds),
      'image': image,
      'type': ConversationType.group.toJson()
    };
  }

  @override
  List<Object?> get props => [
    name,
    visibility,
    memberIds,
    image,
  ];
}
