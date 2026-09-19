import 'package:equatable/equatable.dart';
import 'package:social_app/core/enums/app_enums.dart';

/// The final "ready to send" payload for POST /conversations/:id/messages.
/// Any attachment has already been uploaded to Cloudinary by this point
/// (see CloudinaryUploadService) — this carries only the resulting URL and
/// metadata, never raw bytes, since the endpoint is now plain JSON.
class CreateMessageModel extends Equatable {
  const CreateMessageModel({
    required this.type,
    this.content,
    this.replyToId,
    this.mentionedUserIds,
    this.durationSeconds,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.fileResourceType,
    this.fileFormat,
  });

  final MessageType type;
  final String? content;
  final String? replyToId;
  final List<String>? mentionedUserIds;
  final int? durationSeconds;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;

  /// 'image' | 'video', echoed from Cloudinary's upload response.
  final String? fileResourceType;

  /// e.g. 'jpg', 'mp4', 'm4a', echoed from Cloudinary's upload response.
  final String? fileFormat;

  Map<String, dynamic> toJson() {
    return {
      'type': type.toJson(),
      if (content != null) 'content': content,
      if (replyToId != null) 'replyToId': replyToId,
      if (mentionedUserIds != null && mentionedUserIds!.isNotEmpty)
        'mentionedUserIds': mentionedUserIds,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
      if (fileResourceType != null) 'fileResourceType': fileResourceType,
      if (fileFormat != null) 'fileFormat': fileFormat,
    };
  }

  @override
  List<Object?> get props => [
    type,
    content,
    replyToId,
    mentionedUserIds,
    durationSeconds,
    fileUrl,
    fileName,
    fileSize,
    fileResourceType,
    fileFormat,
  ];
}
