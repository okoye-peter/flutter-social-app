import 'package:dio/dio.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/models/sound_model.dart';

class SoundRepository {
  final Dio _dio = getIt<Dio>();

  Future<List<SoundModel>> listSounds({int limit = 50}) async {
    try {
      final result = await _dio.get(
        '/sounds',
        queryParameters: {'limit': limit},
      );
      final items = result.data['items'] as List<dynamic>? ?? [];
      return items
          .map((item) => SoundModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e, 'Failed to load sounds');
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
