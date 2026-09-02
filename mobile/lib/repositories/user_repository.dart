import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/errors/dio_error_mapper.dart';
import 'package:social_app/core/storage/user_cache.dart';
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
      final data = imageBytes != null
          ? FormData.fromMap({
              'name': user.name,
              'username': user.username,
              'email': user.email,
              'phoneNumber': user.phoneNumber,
              'aboutMe': user.aboutMe,
              'image': MultipartFile.fromBytes(
                imageBytes,
                filename: imageFileName ?? 'avatar.jpg',
              ),
            })
          : user.toJson();

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
}
