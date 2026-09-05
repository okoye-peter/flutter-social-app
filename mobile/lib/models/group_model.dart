import 'package:equatable/equatable.dart';

enum GroupJoinStatus {
  member,
  pending,
  none;

  static GroupJoinStatus fromJson(String? value) {
    switch (value) {
      case 'MEMBER':
        return GroupJoinStatus.member;
      case 'PENDING':
        return GroupJoinStatus.pending;
      default:
        return GroupJoinStatus.none;
    }
  }
}

class GroupModel extends Equatable {
  final String id;
  final String name;
  final String image;
  final String visibility;
  final int memberCount;
  final String createdAt;
  final GroupJoinStatus joinStatus;

  const GroupModel({
    required this.id,
    required this.name,
    required this.image,
    required this.visibility,
    required this.memberCount,
    required this.createdAt,
    this.joinStatus = GroupJoinStatus.none,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      visibility: json['visibility'] ?? '',
      memberCount: json['memberCount'] ?? 0,
      createdAt: json['createdAt'] ?? '',
      joinStatus: GroupJoinStatus.fromJson(json['joinStatus'] as String?),
    );
  }

  @override
  List<Object> get props => [id, name, image, visibility, memberCount, createdAt, joinStatus];
}
