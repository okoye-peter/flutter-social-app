import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:social_app/core/enums/app_enums.dart';

class CreatePostModel extends Equatable {
  final String? kind;
  final String caption;
  final List<String>? taggedUserIds;
  final String? soundId;

  /// Only meaningful when [file] is set; picks the multipart content-type
  /// the repository uploads it as.
  final MediaType? mediaType;
  final Uint8List? file;

  const CreatePostModel({
    required this.kind,
    required this.caption,
    this.taggedUserIds,
    this.soundId,
    this.file,
    this.mediaType,
  });

  Map<String, dynamic> toJson() {
    return {
      if (kind != null) 'kind': kind,
      'caption': caption,
      if (taggedUserIds != null && taggedUserIds!.isNotEmpty)
        'taggedUserIds': jsonEncode(taggedUserIds),
      if (soundId != null) 'soundId': soundId,
    };
  }

  @override
  List<Object?> get props => [kind, caption, taggedUserIds, soundId, file, mediaType];
}
