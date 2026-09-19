import 'package:equatable/equatable.dart';

/// A signed Cloudinary direct-upload authorization from
/// POST /conversations/:id/upload-auth. The client must send back exactly
/// these signed fields (timestamp, folder, allowedFormats) plus apiKey and
/// signature, or Cloudinary's signature check fails.
class CloudinaryUploadAuthModel extends Equatable {
  const CloudinaryUploadAuthModel({
    required this.cloudName,
    required this.apiKey,
    required this.timestamp,
    required this.signature,
    required this.folder,
    required this.allowedFormats,
    required this.resourceType,
  });

  final String cloudName;
  final String apiKey;
  final int timestamp;
  final String signature;
  final String folder;
  final String allowedFormats;

  /// 'image' | 'video' — picks the Cloudinary upload endpoint path.
  final String resourceType;

  factory CloudinaryUploadAuthModel.fromJson(Map<String, dynamic> json) {
    return CloudinaryUploadAuthModel(
      cloudName: json['cloudName'] as String,
      apiKey: json['apiKey'] as String,
      timestamp: json['timestamp'] as int,
      signature: json['signature'] as String,
      folder: json['folder'] as String,
      allowedFormats: json['allowedFormats'] as String,
      resourceType: json['resourceType'] as String,
    );
  }

  @override
  List<Object?> get props => [
    cloudName,
    apiKey,
    timestamp,
    signature,
    folder,
    allowedFormats,
    resourceType,
  ];
}
