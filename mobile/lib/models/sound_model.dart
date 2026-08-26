import 'package:equatable/equatable.dart';
import 'package:social_app/models/user_model.dart';

class SoundModel extends Equatable {
  final String id;
  final String sourcePostId;
  final String creatorId;
  final String title;
  final String audioUrl;
  final int usageCount;
  final DateTime createdAt;
  final UserModel? user;

  const SoundModel({
    required this.id,
    required this.sourcePostId,
    required this.creatorId,
    required this.title,
    required this.audioUrl,
    required this.createdAt,
    this.usageCount = 0,
    this.user,
  });

  factory SoundModel.fromJson(Map<String, dynamic> json) {
    return SoundModel(
      id: json['id'],
      sourcePostId: json['sourcePostId'],
      creatorId: json['creatorId'],
      title: json['title'],
      audioUrl: json['audioUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      usageCount: json['usageCount'] ?? 0,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourcePostId': sourcePostId,
      'creatorId': creatorId,
      'title': title,
      'audioUrl': audioUrl,
      'createdAt': createdAt.toIso8601String(),
      'usageCount': usageCount,
      'user': user?.toJson(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    sourcePostId,
    creatorId,
    title,
    audioUrl,
    createdAt,
    usageCount,
    user,
  ];
}
