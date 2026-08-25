import 'package:social_app/core/enums/app_enums.dart';

/// File extension for a given [MediaType] — used as the filename
/// `MultipartFile.fromBytes` uploads media under. Dio infers the correct
/// multipart Content-Type from that extension automatically, so callers
/// never need to build a `MediaType` (the http_parser one) by hand.
///
/// Callers must only pass `image`/`video` — there's no file to upload for
/// `text`, so callers are expected to have already guarded on that.
String mediaUploadExtension(MediaType mediaType) {
  return switch (mediaType) {
    MediaType.image => 'jpg',
    MediaType.video => 'mp4',
    MediaType.text => throw ArgumentError('MediaType.text has no media to upload'),
  };
}
