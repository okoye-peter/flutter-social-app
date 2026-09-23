import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/errors/dio_error_mapper.dart';
import 'package:social_app/models/conversation_model.dart';
import 'package:social_app/models/group_chat_model.dart';
import 'package:social_app/models/group_join_request_model.dart';
import 'package:social_app/models/group_model.dart';
import 'package:social_app/models/paginate_data_model.dart';

/// Outcome of POST /conversations/:id/join — PUBLIC groups add the caller
/// straight away, PRIVATE groups create a request an admin must approve.
enum GroupJoinResult { joined, requested }

/// Every GROUP-specific endpoint under /conversations. Group messages
/// themselves go through [ChatRepository] like any other conversation.
class GroupRepository {
  final Dio _dio = getIt<Dio>();

  Future<PaginateDataModel<GroupChatModel>> fetchMyGroups({
    String? query,
    String? cursor,
  }) async {
    try {
      final result = await _dio.get(
        '/conversations/groups',
        queryParameters: {'q': ?query, 'cursor': ?cursor},
      );
      return PaginateDataModel.fromJson(
        result.data as Map<String, dynamic>,
        GroupChatModel.fromJson,
      );
    } on DioException catch (e) {
      throw e.toAppException('Failed to load your groups');
    }
  }

  Future<PaginateDataModel<GroupModel>> searchGroups({
    required String query,
    String? cursor,
  }) async {
    try {
      final result = await _dio.get(
        '/conversations/groups/search',
        queryParameters: {'q': query, 'cursor': ?cursor},
      );
      return PaginateDataModel.fromJson(
        result.data as Map<String, dynamic>,
        GroupModel.fromJson,
      );
    } on DioException catch (e) {
      throw e.toAppException('Search failed');
    }
  }

  Future<ConversationModel> createGroup({
    required String name,
    required ConversationVisibility visibility,
    required List<String> memberIds,
    Uint8List? imageBytes,
  }) async {
    try {
      // multipart, not JSON: the endpoint takes an optional image file, and
      // memberIds must be a JSON-encoded string in that form (the backend's
      // optionalJsonStringArray parses it back).
      final data = FormData.fromMap({
        'type': ConversationType.group.toJson(),
        'name': name,
        'visibility': visibility.toJson(),
        'memberIds': jsonEncode(memberIds),
        if (imageBytes != null)
          'image': MultipartFile.fromBytes(imageBytes, filename: 'group.jpg'),
      });
      final result = await _dio.post('/conversations', data: data);
      return ConversationModel.fromJson(
        (result.data as Map<String, dynamic>)['conversation'],
      );
    } on DioException catch (e) {
      throw e.toAppException('Failed to create group');
    }
  }

  Future<ConversationModel> getGroup(String conversationId) async {
    try {
      final result = await _dio.get('/conversations/$conversationId');
      return ConversationModel.fromJson(
        (result.data as Map<String, dynamic>)['conversation'],
      );
    } on DioException catch (e) {
      throw e.toAppException('Failed to load group');
    }
  }

  Future<ConversationModel> updateGroup(
    String conversationId, {
    String? name,
    ConversationVisibility? visibility,
    Uint8List? imageBytes,
  }) async {
    try {
      final data = FormData.fromMap({
        'name': ?name,
        'visibility': ?visibility?.toJson(),
        if (imageBytes != null)
          'image': MultipartFile.fromBytes(imageBytes, filename: 'group.jpg'),
      });
      final result = await _dio.put('/conversations/$conversationId', data: data);
      return ConversationModel.fromJson(
        (result.data as Map<String, dynamic>)['conversation'],
      );
    } on DioException catch (e) {
      throw e.toAppException('Failed to update group');
    }
  }

  Future<ConversationModel> addMembers(
    String conversationId,
    List<String> memberIds,
  ) async {
    try {
      final result = await _dio.post(
        '/conversations/$conversationId/members',
        data: {'memberIds': memberIds},
      );
      return ConversationModel.fromJson(
        (result.data as Map<String, dynamic>)['conversation'],
      );
    } on DioException catch (e) {
      throw e.toAppException('Failed to add members');
    }
  }

  Future<void> removeMember(String conversationId, String userId) async {
    try {
      await _dio.delete('/conversations/$conversationId/members/$userId');
    } on DioException catch (e) {
      throw e.toAppException('Failed to remove member');
    }
  }

  Future<void> leaveGroup(String conversationId) async {
    try {
      await _dio.post('/conversations/$conversationId/leave');
    } on DioException catch (e) {
      throw e.toAppException('Failed to leave group');
    }
  }

  Future<GroupJoinResult> joinGroup(String conversationId) async {
    try {
      final result = await _dio.post('/conversations/$conversationId/join');
      final status = (result.data as Map<String, dynamic>)['status'];
      return status == 'JOINED' ? GroupJoinResult.joined : GroupJoinResult.requested;
    } on DioException catch (e) {
      throw e.toAppException('Failed to join group');
    }
  }

  Future<void> cancelJoinRequest(String conversationId) async {
    try {
      await _dio.delete('/conversations/$conversationId/join');
    } on DioException catch (e) {
      throw e.toAppException('Failed to cancel request');
    }
  }

  Future<List<GroupJoinRequestModel>> fetchJoinRequests(String conversationId) async {
    try {
      final result = await _dio.get('/conversations/$conversationId/join-requests');
      final items = (result.data as Map<String, dynamic>)['items'] as List;
      return items
          .map((e) => GroupJoinRequestModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw e.toAppException('Failed to load join requests');
    }
  }

  Future<void> respondToJoinRequest(
    String conversationId,
    String requestId, {
    required bool accept,
  }) async {
    try {
      await _dio.post(
        '/conversations/$conversationId/join-requests/$requestId',
        data: {'accept': accept},
      );
    } on DioException catch (e) {
      throw e.toAppException('Failed to respond to request');
    }
  }
}
