import 'package:dio/dio.dart';
import 'package:social_app/core/errors/app_exception.dart';

extension CloudinaryErrorMapper on DioException {
  /// Cloudinary's error body is `{"error": {"message": "..."}}` — an
  /// object, not the backend's `{"error": "string"}` — so DioErrorMapper's
  /// toAppException would throw on the type cast if reused here.
  AppException toCloudinaryAppException(String fallback) {
    final data = response?.data;
    String? message;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) message = error['message'] as String?;
    }
    return AppException(message ?? fallback, statusCode: response?.statusCode);
  }
}
