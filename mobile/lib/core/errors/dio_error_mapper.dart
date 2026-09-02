import 'package:dio/dio.dart';
import 'package:social_app/core/errors/app_exception.dart';

extension DioErrorMapper on DioException {
  /// Prefers the backend's `error` message when present, falling back to
  /// [fallback] otherwise (e.g. for network failures with no response).
  AppException toAppException(String fallback) {
    final data = response?.data;
    final message = data is Map ? data['error'] as String? : null;
    return AppException(message ?? fallback, statusCode: response?.statusCode);
  }
}
