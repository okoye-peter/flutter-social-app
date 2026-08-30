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
      final data = result.data as Map<String, dynamic>;
      return PostModel.fromJson(data['post'] as Map<String, dynamic>);
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

  Future<PostModel> getPostDetails(String postId) async {
    try {
      final result = await _dio.get('/posts/$postId');
      final data = result.data as Map<String, dynamic>;
      return PostModel.fromJson(data['post']);
    } on DioException catch (e) {
      throw _mapError(e, 'Failed to load posts');
    }
  }

  Future<({int likesCount})> togglePostLike(PostModel post) async {
    try {
      final result = post.likedByMe
          ? await _dio.delete('/posts/${post.id}/likes')
          : await _dio.post('/posts/${post.id}/likes');
      final data = result.data as Map<String, dynamic>;
      return (likesCount: data['likesCount'] as int);
    } on DioException catch (e) {
      throw _mapError(
        e,
        post.likedByMe == true
            ? 'Failed to unlike post'
            : 'Failed to like post',
      );
    }
  }

  Future<({int bookmarksCount})> togglePostBookMark(PostModel post) async {
    try {
      final result = post.bookmarkedByMe
          ? await _dio.delete('posts/${post.id}/bookmarks')
          : await _dio.post('posts/${post.id}/bookmarks');

      final data = result.data as Map<String, dynamic>;
      return (bookmarksCount: data['bookmarksCount'] as int);
    } on DioException catch (e) {
      throw _mapError(
        e,
        post.likedByMe == true
            ? 'Failed to remove post for bookmark'
            : 'Failed to bookmark post',
      );
    }
  }

  Future<({int repostsCount})> togglePostRepost(
    PostModel post, {
    String? comment,
  }) async {
    try {
      final result = post.repostedByMe
          ? await _dio.delete('posts/${post.id}/reposts')
          : await _dio.post(
              'posts/${post.id}/reposts',
              data: {comment: comment ?? ''},
            );

      final data = result.data as Map<String, dynamic>;
      return (repostsCount: data['repostsCount'] as int);
    } on DioException catch (e) {
      throw _mapError(
        e,
        post.repostedByMe == true
            ? 'Failed to remove repost'
            : 'Failed to repost',
      );
    }
  }

  Future repost({required String postId, String? comment}) async {
    try {
      final result = await _dio.post(
        '/posts/$postId/reposts',
        data: {comment: comment},
      );
    } on DioException catch (e) {}
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
