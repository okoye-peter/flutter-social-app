import 'package:dio/dio.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/errors/dio_error_mapper.dart';
import 'package:social_app/models/chat_user_model.dart';
import 'package:social_app/models/cloudinary_upload_auth_model.dart';
import 'package:social_app/models/conversation_model.dart';
import 'package:social_app/models/create_message_model.dart';
import 'package:social_app/models/message_model.dart';
import 'package:social_app/models/paginate_data_model.dart';
import 'package:social_app/models/user_model.dart';

class ChatRepository {
  final Dio _dio = getIt<Dio>();

  Future<PaginateDataModel<ChatUserModel>> searchUsersWithChat({
    String? query,
    String? cursor,
  }) async {
    try {
      final response = await _dio.get(
        '/conversations/direct',
        queryParameters: {'q': ?query, 'cursor': ?cursor},
      );
      return PaginateDataModel.fromJson(
        response.data as Map<String, dynamic>,
        ChatUserModel.fromJson,
      );
    } on DioException catch (e) {
      throw e.toAppException(e.message ?? 'Failed to search users');
    }
  }

  Future<PaginateDataModel<UserModel>> searchUsersWithOutChat({
    required String query,
    String? cursor,
  }) async {
    try {
      final response = await _dio.get(
        '/conversations/contacts',
        queryParameters: {'q': query, 'cursor': ?cursor},
      );
      return PaginateDataModel.fromJson(
        response.data as Map<String, dynamic>,
        UserModel.fromJson,
      );
    } on DioException catch (e) {
      throw e.toAppException(e.message ?? 'Failed to search users');
    }
  }

  Future<ConversationModel> createDirectChat({required String userId}) async {
    try {
      final result = await _dio.post(
        '/conversations',
        data: {
          'participantId': userId,
          'type': ConversationType.direct.toJson(),
        },
      );
      final data = result.data as Map<String, dynamic>;
      return ConversationModel.fromJson(data['conversation']);
    } on DioException catch (e) {
      throw e.toAppException(e.message ?? 'Failed to create direct chat');
    }
  }

  Future<ConversationModel> getConversation({
    required String conversationId,
  }) async {
    try {
      final result = await _dio.get('/conversations/$conversationId');
      final data = result.data as Map<String, dynamic>;
      return ConversationModel.fromJson(data['conversation']);
    } on DioException catch (e) {
      throw e.toAppException(e.message ?? 'Failed to fetch conversation');
    }
  }

  Future<CloudinaryUploadAuthModel> getUploadAuth({
    required String conversationId,
    required MessageType type,
  }) async {
    try {
      final result = await _dio.post(
        '/conversations/$conversationId/upload-auth',
        data: {'type': type.toJson()},
      );
      return CloudinaryUploadAuthModel.fromJson(
        result.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw e.toAppException(e.message ?? 'Failed to prepare upload');
    }
  }

  Future<MessageModel> sendMessage({
    required String conversationId,
    required CreateMessageModel message,
  }) async {
    try {
      final result = await _dio.post(
        '/conversations/$conversationId/messages',
        data: message.toJson(),
      );
      final data = result.data as Map<String, dynamic>;
      return MessageModel.fromJson(data['message'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.toAppException(e.message ?? 'Failed to send message');
    }
  }

  Future<void> markRead({
    required String conversationId,
    required String upToMessageId,
  }) async {
    try {
      await _dio.post(
        '/conversations/$conversationId/read',
        data: {'upToMessageId': upToMessageId},
      );
    } on DioException catch (e) {
      throw e.toAppException('Failed to mark messages as read');
    }
  }

  Future<PaginateDataModel<MessageModel>> fetchMessages({
    required String conversationId,
    String? cursor,
  }) async {
    try {
      final result = await _dio.get(
        '/conversations/$conversationId/messages',
        queryParameters: {'cursor': ?cursor},
      );
      return PaginateDataModel<MessageModel>.fromJson(
        result.data as Map<String, dynamic>,
        MessageModel.fromJson,
      );
    } on DioException catch (e) {
      throw e.toAppException(e.message ?? 'Failed to fetch messages');
    }
  }

  /// Sets (or replaces) the caller's reaction on a message — one per user.
  Future<void> reactToMessage({required String messageId, required String emoji}) async {
    try {
      await _dio.post('/messages/$messageId/reactions', data: {'emoji': emoji});
    } on DioException catch (e) {
      throw e.toAppException('Failed to react');
    }
  }

  Future<void> removeReaction({required String messageId}) async {
    try {
      await _dio.delete('/messages/$messageId/reactions');
    } on DioException catch (e) {
      throw e.toAppException('Failed to remove reaction');
    }
  }
}
