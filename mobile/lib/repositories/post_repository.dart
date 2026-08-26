import 'package:dio/dio.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/core/utils/media_upload.dart';
import 'package:social_app/models/create_post_model.dart';
import 'package:social_app/models/post_model.dart';
import 'package:social_app/models/posts_page.dart';

class PostRepository {
  final Dio _dio = getIt<Dio>();

  Future<PostModel> createPost(CreatePostModel post) async {
    try {
      final formData = FormData.fromMap(post.toJson());

      final file = post.file;
      final mediaType = post.mediaType;
      if (file != null && mediaType != null) {
        formData.files.add(
          MapEntry(
            'media',
            MultipartFile.fromBytes(
              file,
              filename: 'post_media.${mediaUploadExtension(mediaType)}',
            ),
          ),
        );
      }

      final result = await _dio.post('/posts', data: formData);
      return PostModel.fromJson(result.data.post);
    } on DioException catch (e) {
      throw _mapError(e, 'Failed to create post');
    }
  }

  Future<PostsPage> fetchPosts({String? cursor, int? limit}) async {
    try {
      final result = await _dio.get(
        '/posts',
        queryParameters: {'cursor': ?cursor, 'limit': ?limit},
      );
      return PostsPage.fromJson(result.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e, 'Failed to load posts');
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
