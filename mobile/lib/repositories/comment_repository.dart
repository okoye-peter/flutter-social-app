import 'package:dio/dio.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/errors/dio_error_mapper.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/comment_model.dart';
import 'package:social_app/models/create_comment_model.dart';
import 'package:social_app/models/paginate_data_model.dart';

class CommentRepository {
  final Dio _dio = getIt<Dio>();

  Future<CommentModel> createComment({
    required String postId,
    required CreateCommentModel comment,
  }) async {
    try {
      final result = await _dio.post(
        '/posts/$postId/comments',
        data: comment.toJson(),
      );
      final data = result.data as Map<String, dynamic>;
      final user = getIt<UserCache>().current;
      data['comment']['user'] = user?.toJson();
      return CommentModel.fromJson(data['comment']);
    } on DioException catch (e) {
      throw e.toAppException('Failed to comment on post');
    }
  }

  Future<PaginateDataModel<CommentModel>> listComments({
    required String postId,
    String? cursor,
    int? limit,
  }) async {
    try {
      final result = await _dio.get(
        '/posts/$postId/comments',
        queryParameters: {'cursor': ?cursor, 'limit': ?limit},
      );
      return PaginateDataModel.fromJson(
        result.data as Map<String, dynamic>,
        CommentModel.fromJson,
      );
    } on DioException catch (e) {
      throw e.toAppException('Failed to load comments');
    }
  }

  Future<void> deleteComment(CommentModel comment) async {
    try {
      await _dio.delete('/comments/${comment.id}');
    } on DioException catch (e) {
      throw e.toAppException('Failed to delete comment');
    }
  }

  Future<CommentModel> updateComment(CommentModel comment) async {
    try {
      final result = await _dio.put(
        '/comments/${comment.id}',
        data: {'content': comment.content},
      );
      final data = result.data as Map<String, dynamic>;
      final user = getIt<UserCache>().current;
      data['comment']['user'] = user?.toJson();
      return CommentModel.fromJson(data['comment']);
    } on DioException catch (e) {
      throw e.toAppException('Failed to update comment');
    }
  }

  Future<({int likesCount})> likeComment(String commentId) async {
    try {
      final result = await _dio.post('/comments/$commentId/likes');
      final data = result.data as Map<String, dynamic>;
      return (likesCount: data['likesCount'] as int);
    } on DioException catch (e) {
      throw e.toAppException('Failed to like comment');
    }
  }

  Future<({int likesCount})> unlikeComment(String commentId) async {
    try {
      final result = await _dio.delete('/comments/$commentId/likes');
      final data = result.data as Map<String, dynamic>;
      return (likesCount: data['likesCount'] as int);
    } on DioException catch (e) {
      throw e.toAppException('Failed to unlike comment');
    }
  }

  Future<PaginateDataModel<CommentModel>> getCommentReplies({
    required String commentId,
    String? cursor,
    int? limit,
  }) async {
    try {
      final result = await _dio.get(
        '/comments/$commentId/replies',
        queryParameters: {'cursor': ?cursor, 'limit': ?limit},
      );
      return PaginateDataModel.fromJson(
        result.data as Map<String, dynamic>,
        CommentModel.fromJson,
      );
    } on DioException catch (e) {
      throw e.toAppException('Failed to load replies');
    }
  }
}
