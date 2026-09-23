import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/errors/dio_error_mapper.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/paginate_data_model.dart';
import 'package:social_app/models/post_model.dart';
import 'package:social_app/models/user_model.dart';

class UserRepository {
  final Dio _dio = getIt<Dio>();
  final UserCache _userCache = getIt<UserCache>();

  Future<UserModel> updateUser(
    UserModel user, {
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    try {
      // The backend's updateProfile only ever reads name/aboutMe (and the
      // image file) — sending the rest of UserModel.toJson() here doesn't
      // do anything today, but it's a trap for whoever next adds a field
      // to this payload expecting the server to actually look at it.
      final data = imageBytes != null
          ? FormData.fromMap({
              'name': user.name,
              'aboutMe': user.aboutMe,
              'image': MultipartFile.fromBytes(
                imageBytes,
                filename: imageFileName ?? 'avatar.jpg',
              ),
            })
          : {'name': user.name, 'aboutMe': user.aboutMe};

      final result = await _dio.put('/users/profile', data: data);
      final updated = UserModel.fromJson(
        (result.data as Map<String, dynamic>)['user'],
      );
      await _userCache.save(updated);
      return updated;
    } on DioException catch (e) {
      throw e.toAppException('Profile update failed');
    }
  }

  Future<PaginateDataModel<UserModel>> searchUsers(
    String query, {
    String? cursor,
  }) async {
    try {
      final result = await _dio.get('/users/search', queryParameters: {
        'q': query,
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
      });
      return PaginateDataModel.fromJson(
        result.data as Map<String, dynamic>,
        UserModel.fromJson,
      );
    } on DioException catch (e) {
      throw e.toAppException('User search failed');
    }
  }

  Future<({int followersCount})> toggleFollow(UserModel user) async {
    try {
      final result = user.isFollowedByMe
          ? await _dio.delete('/users/${user.id}/follow')
          : await _dio.post('/users/${user.id}/follow');
      final data = result.data as Map<String, dynamic>;
      return (followersCount: data['followersCount'] as int);
    } on DioException catch (e) {
      throw e.toAppException(
        user.isFollowedByMe ? 'Failed to unfollow user' : 'Failed to follow user',
      );
    }
  }

  Future<({UserModel user, bool isFollowedByMe, bool isBlockedByMe})> getUserProfile(
    String userId,
  ) async {
    try {
      final result = await _dio.get('/users/$userId');
      final data = result.data as Map<String, dynamic>;
      return (
        user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
        isFollowedByMe: data['isFollowedByMe'] as bool? ?? false,
        isBlockedByMe: data['isBlockedByMe'] as bool? ?? false,
      );
    } on DioException catch (e) {
      throw e.toAppException('Failed to load profile');
    }
  }

  Future<PaginateDataModel<PostModel>> _fetchUserTab(
    String userId,
    String endpointSuffix, {
    String? cursor,
    int? limit,
  }) async {
    try {
      final result = await _dio.get(
        '/users/$userId/$endpointSuffix',
        queryParameters: {'cursor': ?cursor, 'limit': ?limit},
      );
      return PaginateDataModel.fromJson(
        result.data as Map<String, dynamic>,
        PostModel.fromJson,
      );
    } on DioException catch (e) {
      throw e.toAppException('Failed to load $endpointSuffix');
    }
  }

  Future<PaginateDataModel<PostModel>> fetchUserPosts(
    String userId, {
    String? cursor,
    int? limit,
  }) => _fetchUserTab(userId, 'posts', cursor: cursor, limit: limit);

  Future<PaginateDataModel<PostModel>> fetchUserReels(
    String userId, {
    String? cursor,
    int? limit,
  }) => _fetchUserTab(userId, 'reels', cursor: cursor, limit: limit);

  Future<PaginateDataModel<PostModel>> fetchUserReposts(
    String userId, {
    String? cursor,
    int? limit,
  }) => _fetchUserTab(userId, 'reposts', cursor: cursor, limit: limit);

  Future<PaginateDataModel<PostModel>> fetchUserTagged(
    String userId, {
    String? cursor,
    int? limit,
  }) => _fetchUserTab(userId, 'tagged', cursor: cursor, limit: limit);
}
