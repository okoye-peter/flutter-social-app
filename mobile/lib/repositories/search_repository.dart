import 'package:dio/dio.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/errors/dio_error_mapper.dart';
import 'package:social_app/models/group_model.dart';
import 'package:social_app/models/user_model.dart';

class SearchRepository {
  final Dio _dio = getIt<Dio>();

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final result = await _dio.get('/users/search', queryParameters: {'q': query});
      final items = (result.data['items'] as List).cast<Map<String, dynamic>>();
      return items.map(UserModel.fromJson).toList();
    } on DioException catch (e) {
      throw e.toAppException('Search failed');
    }
  }

  Future<List<GroupModel>> searchGroups(String query) async {
    try {
      final result = await _dio.get('/conversations/groups/search', queryParameters: {'q': query});
      final items = (result.data['items'] as List).cast<Map<String, dynamic>>();
      return items.map(GroupModel.fromJson).toList();
    } on DioException catch (e) {
      throw e.toAppException('Search failed');
    }
  }
}
