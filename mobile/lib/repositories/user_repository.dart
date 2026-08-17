import 'package:dio/dio.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/user_model.dart';

class UserRepository {
  final Dio _dio = getIt<Dio>();
  final UserCache _userCache = getIt<UserCache>();

  Future<UserModel> updateUser(UserModel user) async {
    try {
      final result = await _dio.put('/auth/profile', data: user.toJson());
      final updated = UserModel.fromJson(
        (result.data as Map<String, dynamic>)['user'],
      );
      await _userCache.save(updated);
      return updated;
    } on DioException catch (e) {
      throw _mapError(e, 'Profile update failed');
    }
  }

  AppException _mapError(DioException e, String fallback) {
    final data = e.response?.data;
    final message = data is Map ? data['error'] as String? : null;
    return AppException(
      message ?? fallback,
      statusCode: e.response?.statusCode,
    );
  }
}
