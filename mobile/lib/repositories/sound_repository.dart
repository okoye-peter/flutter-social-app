import 'package:dio/dio.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/errors/dio_error_mapper.dart';
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
      throw e.toAppException('Failed to load sounds');
    }
  }
}
