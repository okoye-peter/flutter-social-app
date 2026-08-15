import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:social_app/core/constants/api_constants.dart';
import 'package:social_app/core/storage/token_storage.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/auth_tokens.dart';

const _refreshPath = '/auth/refresh';

class DioClient {
  DioClient._();

  static Dio create(TokenStorage tokenStorage, UserCache userCache) {
    print(ApiConstants.baseUrl);
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final accessToken = tokenStorage.current?.accessToken;
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          handler.next(options);
        },
      ),
    );

    Future<AuthTokens?>? refreshFuture;

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final options = error.requestOptions;
          final isUnauthorized = error.response?.statusCode == 401;
          final isRefreshCall = options.path == _refreshPath;
          final alreadyRetried = options.extra['isRetry'] == true;

          if (!isUnauthorized || isRefreshCall || alreadyRetried) {
            return handler.next(error);
          }

          try {
            refreshFuture ??= _refreshTokens(dio, tokenStorage);
            final newTokens = await refreshFuture;
            refreshFuture = null;

            if (newTokens == null) {
              await tokenStorage.clear();
              await userCache.clear();
              return handler.next(error);
            }

            options.extra['isRetry'] = true;
            options.headers['Authorization'] =
                'Bearer ${newTokens.accessToken}';
            final response = await dio.fetch(options);
            return handler.resolve(response);
          } catch (_) {
            refreshFuture = null;
            await tokenStorage.clear();
            await userCache.clear();
            return handler.next(error);
          }
        },
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }

    return dio;
  }

  static Future<AuthTokens?> _refreshTokens(
    Dio dio,
    TokenStorage tokenStorage,
  ) async {
    final refreshToken = tokenStorage.current?.refreshToken;
    if (refreshToken == null) return null;

    final response = await dio.post(
      _refreshPath,
      data: {'refreshToken': refreshToken},
    );
    final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
    await tokenStorage.save(tokens);
    return tokens;
  }
}
