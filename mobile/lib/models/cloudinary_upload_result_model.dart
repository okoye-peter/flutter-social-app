import 'package:equatable/equatable.dart';

/// Cloudinary's own response from a direct upload — feeds into a
/// CreateMessageModel's fileUrl/fileSize/fileResourceType/fileFormat.
/// fileName is NOT sourced from here; it comes from the original
/// PendingAttachment instead.
class CloudinaryUploadResultModel extends Equatable {
  const CloudinaryUploadResultModel({
    required this.secureUrl,
    required this.bytes,
    required this.resourceType,
    required this.format,
  });

  final String secureUrl;
  final int bytes;
  final String resourceType;
  final String format;

  factory CloudinaryUploadResultModel.fromJson(Map<String, dynamic> json) {
    return CloudinaryUploadResultModel(
      secureUrl: json['secure_url'] as String,
      bytes: json['bytes'] as int,
      resourceType: json['resource_type'] as String,
      format: json['format'] as String,
    );
  }

  @override
  List<Object?> get props => [secureUrl, bytes, resourceType, format];
}
