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
    this.senderName,
    this.senderImage,
    this.content,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.duration,
    this.replyToId,
    this.replyTo,
    this.reactions = const {},
    this.deletedAt,
  });

  final String id;
  final String conversationId;
  // Nullable: SYSTEM messages (e.g. "X joined the group") have no sender.
  final String? senderId;
  // Only present on GET /conversations/:id/messages rows (nested `sender`)
  // — a live `message:new` or a send response carries just senderId, so a
  // group chat resolves names from its member list first and uses these as
  // the fallback for people who have since left.
  final String? senderName;
  final String? senderImage;
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
  // Preview of the message this one replies to — sent by the backend on
  // sends, `message:new` and message lists, so a quote renders even when
  // its parent is outside the loaded page.
  final MessageReplyPreview? replyTo;
  // userId -> emoji, one reaction per person. Only message lists carry
  // this; live changes arrive as `message:reaction(-removed)` events.
  final Map<String, String> reactions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  @override
  List<Object?> get props => [
    id,
    conversationId,
    senderId,
    senderName,
    senderImage,
    type,
    content,
    fileUrl,
    fileName,
    fileSize,
    duration,
    replyToId,
    replyTo,
    reactions,
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
    Map<String, String>? reactions,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName,
      senderImage: senderImage,
      type: type ?? this.type,
      content: content ?? this.content,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      replyToId: replyToId ?? this.replyToId,
      replyTo: replyTo,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      // POST /conversations/:id/messages (create) returns a flat
      // senderId. GET /conversations/:id/messages (list) strips senderId
      // and nests a sender: {id, ...} object instead (to also carry
      // reaction/read-receipt info) — fall back to that shape too, or
      // "is this my message" silently breaks on every refetch.
      senderId: json['senderId'] as String? ?? sender?['id'] as String?,
      senderName: sender?['name'] as String?,
      senderImage: sender?['image'] as String?,
      type: MessageType.fromJson(json['type'] as String?),
      content: json['content'] as String?,
      fileUrl: json['fileUrl'] as String?,
      fileName: json['fileName'] as String?,
      fileSize: json['fileSize'] as int?,
      duration: json['duration'] as int?,
      replyToId: json['replyToId'] as String?,
      replyTo: json['replyTo'] is Map
          ? MessageReplyPreview.fromJson(Map<String, dynamic>.from(json['replyTo'] as Map))
          : null,
      reactions: {
        for (final r in (json['reactions'] as List?) ?? const [])
          if (r is Map && r['userId'] is String && r['emoji'] is String)
            r['userId'] as String: r['emoji'] as String,
      },
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
    );
  }
}

/// The quoted part of a reply: who wrote the original and what it said.
class MessageReplyPreview extends Equatable {
  const MessageReplyPreview({
    required this.id,
    required this.type,
    this.senderId,
    this.senderName,
    this.content,
    this.isDeleted = false,
  });

  final String id;
  final MessageType type;
  final String? senderId;
  final String? senderName;
  final String? content;
  final bool isDeleted;

  factory MessageReplyPreview.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return MessageReplyPreview(
      id: json['id'] as String,
      type: MessageType.fromJson(json['type'] as String?),
      senderId: sender?['id'] as String?,
      senderName: sender?['name'] as String?,
      content: json['content'] as String?,
      isDeleted: json['deletedAt'] != null,
    );
  }

  /// Builds a preview from a full message — for quoting a message the
  /// user is replying to before the server has echoed anything back.
  factory MessageReplyPreview.fromMessage(MessageModel message) {
    return MessageReplyPreview(
      id: message.id,
      type: message.type,
      senderId: message.senderId,
      senderName: message.senderName,
      content: message.content,
    );
  }

  /// One-line summary for the quote: the text, or a label for media.
  String get summary {
    if (isDeleted) return 'Message deleted';
    final text = content?.trim();
    if (text != null && text.isNotEmpty) return text;
    return switch (type) {
      MessageType.image => '📷 Photo',
      MessageType.video => '🎥 Video',
      MessageType.voiceNote => '🎤 Voice message',
      MessageType.file => '📎 File',
      MessageType.system || MessageType.text => '',
    };
  }

  @override
  List<Object?> get props => [id, type, senderId, senderName, content, isDeleted];
}
