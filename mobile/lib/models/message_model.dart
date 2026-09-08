import 'package:equatable/equatable.dart';
import 'package:social_app/core/enums/app_enums.dart';

class MessageModel extends Equatable {
  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.senderId,
    this.content,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.duration,
    this.replyToId,
    this.deletedAt,
  });

  final String id;
  final String conversationId;
  // Nullable: SYSTEM messages (e.g. "X joined the group") have no sender.
  final String? senderId;
  final MessageType type;
  // Nullable: only TEXT messages require content — a media message may carry
  // just a file.
  final String? content;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  // Only set for VOICE_NOTE messages.
  final int? duration;
  final String? replyToId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  @override
  List<Object?> get props => [
    id,
    conversationId,
    senderId,
    type,
    content,
    fileUrl,
    fileName,
    fileSize,
    duration,
    replyToId,
    createdAt,
    updatedAt,
    deletedAt,
  ];

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    MessageType? type,
    String? content,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    int? duration,
    String? replyToId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      content: content ?? this.content,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      replyToId: replyToId ?? this.replyToId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String?,
      type: MessageType.fromJson(json['type'] as String?),
      content: json['content'] as String?,
      fileUrl: json['fileUrl'] as String?,
      fileName: json['fileName'] as String?,
      fileSize: json['fileSize'] as int?,
      duration: json['duration'] as int?,
      replyToId: json['replyToId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
    );
  }
}
