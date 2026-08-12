import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:social_app/core/constants/api_constants.dart';

class DioClient {
  DioClient._();

  static Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
    }

    // Auth interceptor (attach access token, refresh on 401) plugs in here
    // once AuthRepository exists — see docs/auth_token_storage.md.

    return dio;
  }
}
