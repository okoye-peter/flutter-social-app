import 'package:dio/dio.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/errors/dio_error_mapper.dart';
import 'package:social_app/models/chat_user_model.dart';
import 'package:social_app/models/paginate_data_model.dart';
import 'package:social_app/models/user_model.dart';

class ChatRepository {
  final Dio _dio = getIt<Dio>();

  Future<PaginateDataModel<ChatUserModel>> searchUsersWithChat({
    required String query,
    String? cursor,
  }) async {
    try {
      final response = await _dio.get(
        '/conversations/direct',
        queryParameters: {
          'q': query,
          if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
        },
      );
      return PaginateDataModel.fromJson(
        response.data as Map<String, dynamic>,
        ChatUserModel.fromJson,
      );
    } on DioException catch (e) {
      throw e.toAppException(e.message ?? 'Failed to search users');
    }
  }

  Future<PaginateDataModel<UserModel>> searchUsersWithOutChat({ required String query, String? cursor }) async {
    try{
      final response = await _dio.get(
        '/conversations/contacts',
        queryParameters: {
          'q': query,
          'cursor': ?cursor,
        },
      );
      return PaginateDataModel.fromJson(
        response.data as Map<String, dynamic>,
        UserModel.fromJson,
      );
    } on DioException catch (e) {
      throw e.toAppException(e.message ?? 'Failed to search users');
    }
  } 

  Future<void> createDirectChat({ required String userId }) async {
    try {
      await _dio.post(
        '/conversations/direct',
        data: {
          'userId': userId,
        },
      );
    } on DioException catch (e) {
      throw e.toAppException(e.message ?? 'Failed to create direct chat');
    }
  }
}
