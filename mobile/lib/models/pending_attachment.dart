import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:social_app/core/enums/app_enums.dart';

/// An attachment the user has picked/recorded but not yet uploaded. This is
/// the lifecycle stage before CreateMessageModel — once
/// CloudinaryUploadService uploads [bytes], the result feeds into a
/// CreateMessageModel's fileUrl/fileSize/fileResourceType/fileFormat.
class PendingAttachment extends Equatable {
  const PendingAttachment({
    required this.bytes,
    required this.fileName,
    required this.messageType,
    this.durationSeconds,
  });

  final Uint8List bytes;
  final String fileName;

  /// Only MessageType.image, .video, or .voiceNote are valid here.
  final MessageType messageType;

  /// Required in practice for MessageType.voiceNote.
  final int? durationSeconds;

  @override
  List<Object?> get props => [bytes, fileName, messageType, durationSeconds];
}
