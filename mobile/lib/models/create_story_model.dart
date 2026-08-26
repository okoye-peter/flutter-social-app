import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:social_app/core/enums/app_enums.dart';

class CreateStoryModel extends Equatable {
  const CreateStoryModel({
    required this.media,
    required this.mediaType,
    this.caption = '',
  });

  final Uint8List media;

  /// Drives the multipart content-type `StoryRepository.createStory`
  /// uploads `media` as — the backend's upload filter only checks this
  /// prefix (image/ vs video/), not an exact subtype.
  final MediaType mediaType;
  final String caption;

  @override
  List<Object> get props => [media, mediaType, caption];

  CreateStoryModel copyWith({
    Uint8List? newMedia,
    MediaType? newMediaType,
    String? newCaption,
  }) {
    return CreateStoryModel(
      media: newMedia ?? media,
      mediaType: newMediaType ?? mediaType,
      caption: newCaption ?? caption,
    );
  }
}
