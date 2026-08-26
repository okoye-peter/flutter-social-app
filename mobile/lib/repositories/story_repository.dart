import 'package:dio/dio.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/core/utils/media_upload.dart';
import 'package:social_app/models/create_story_model.dart';
import 'package:social_app/models/story_model.dart';

class StoryRepository {
  final Dio _dio = getIt<Dio>();

  Future<List<StoryGroupModel>> fetchStoriesFeed() async {
    try {
      final result = await _dio.get('/stories');
      final groups = result.data['groups'] as List<dynamic>;
      return groups
          .map((g) => StoryGroupModel.fromJson(g as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e, 'Failed to load stories');
    }
  }

  Future<void> markStoryViewed(String storyId) async {
    try {
      await _dio.post('/stories/$storyId/views');
    } on DioException catch (e) {
      throw _mapError(e, 'Failed to mark story as viewed');
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

  Future<void> createStory(CreateStoryModel story) async {
    try {
      final formData = FormData.fromMap({
        'caption': story.caption,
        'media': MultipartFile.fromBytes(
          story.media,
          filename: 'story_media.${mediaUploadExtension(story.mediaType)}',
        ),
      });
      await _dio.post('/stories', data: formData);
    } on DioException catch (e) {
      throw _mapError(e, 'Failed to create story');
    }
  }
}
