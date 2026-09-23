import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:social_app/core/errors/cloudinary_error_mapper.dart';
import 'package:social_app/models/cloudinary_upload_auth_model.dart';
import 'package:social_app/models/cloudinary_upload_result_model.dart';

class CloudinaryUploadService {
  // Deliberately NOT getIt<Dio>() — that shared instance unconditionally
  // attaches this app's own bearer token to every request via an
  // interceptor with no host check, which would leak it to Cloudinary. This
  // bare instance has no baseUrl, no auth/refresh/log interceptors.
  final Dio _bareDio = Dio();

  Future<CloudinaryUploadResultModel> upload({
    required CloudinaryUploadAuthModel auth,
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    // TEMP DEBUG — remove once the 400 on voice-note upload is diagnosed.
    debugPrint(
      '[CloudinaryUpload] bytes=${bytes.length} fileName=$fileName '
      'resourceType=${auth.resourceType} folder=${auth.folder} '
      'allowedFormats=${auth.allowedFormats} timestamp=${auth.timestamp}',
    );
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
        'api_key': auth.apiKey,
        'timestamp': auth.timestamp,
        'signature': auth.signature,
        'folder': auth.folder,
        'allowed_formats': auth.allowedFormats,
      });
      final response = await _bareDio.post(
        'https://api.cloudinary.com/v1_1/${auth.cloudName}/${auth.resourceType}/upload',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
        cancelToken: cancelToken,
      );
      return CloudinaryUploadResultModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      // TEMP DEBUG — remove once the 400 on voice-note upload is diagnosed.
      debugPrint(
        '[CloudinaryUpload] FAILED status=${e.response?.statusCode} '
        'body=${e.response?.data}',
      );
      throw e.toCloudinaryAppException('Failed to upload attachment');
    }
  }
}
