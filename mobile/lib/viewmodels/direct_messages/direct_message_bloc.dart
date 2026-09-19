import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/models/create_message_model.dart';
import 'package:social_app/models/message_model.dart';
import 'package:social_app/models/pending_attachment.dart';
import 'package:social_app/repositories/chat_repository.dart';
import 'package:social_app/services/cloudinary_upload_service.dart';

part 'direct_message_event.dart';
part 'direct_message_state.dart';

class DirectMessageBloc extends Bloc<DirectMessageEvent, DirectMessageState> {
  DirectMessageBloc({required this.otherUserId, this._conversationId})
    : super(DirectMessageInitialState()) {
    on<LoadDirectMessagesEvent>(_processLoad, transformer: restartable());
    on<LoadMoreDirectMessagesEvent>(_processLoadMore, transformer: droppable());
    // concurrent(), not droppable(): sending an attachment (slow, mid
    // upload) must not block a text message sent right after — each
    // pending send is tracked independently by its own localId.
    on<SendTextMessageEvent>(_processSendText, transformer: concurrent());
    on<SendAttachmentMessageEvent>(
      _processSendAttachment,
      transformer: concurrent(),
    );
    on<RetrySendMessageEvent>(_processRetry, transformer: concurrent());
    on<CancelSendMessageEvent>(_processCancel, transformer: concurrent());
  }

  /// The other participant — needed to create the conversation on first
  /// send when opening a brand-new chat (see [_conversationId]).
  final String otherUserId;
  final ChatRepository _repo = ChatRepository();
  final CloudinaryUploadService _cloudinary = CloudinaryUploadService();
  final Map<String, CancelToken> _cancelTokens = {};

  // Null when opening a brand-new chat with no conversation yet (matches
  // ChatDetailsArgs.conversationId) — resolved lazily via createDirectChat
  // on the first send, then reused for every send after.
  String? _conversationId;

  String _newLocalId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<String> _ensureConversationId() async {
    final existing = _conversationId;
    if (existing != null) return existing;
    final conversation = await _repo.createDirectChat(userId: otherUserId);
    _conversationId = conversation.id;
    return conversation.id;
  }

  Future<void> _processLoad(
    LoadDirectMessagesEvent event,
    Emitter<DirectMessageState> emit,
  ) async {
    final conversationId = _conversationId;
    if (conversationId == null) {
      // Brand-new chat — nothing to fetch yet.
      emit(const DirectMessageLoadedState(items: []));
      return;
    }
    emit(DirectMessageLoadingState());
    try {
      final result = await _repo.fetchMessages(conversationId: conversationId);
      emit(
        DirectMessageLoadedState(
          items: result.items,
          cursor: result.nextCursor,
          hasMore: result.hasMorePage,
        ),
      );
      _markLatestIncomingRead(conversationId, result.items);
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to load messages';
      emit(DirectMessageErrorState(message: message));
    }
  }

  // Fire-and-forget: a failed mark-read must never affect the thread UI.
  // items is newest-first, so the first message not sent by me is the
  // newest incoming one — marking up to it covers everything before it too.
  void _markLatestIncomingRead(String conversationId, List<MessageModel> items) {
    final myId = getIt<UserCache>().current?.id;
    for (final message in items) {
      if (message.senderId != null && message.senderId != myId) {
        _repo
            .markRead(conversationId: conversationId, upToMessageId: message.id)
            .catchError((_) {});
        return;
      }
    }
  }

  Future<void> _processLoadMore(
    LoadMoreDirectMessagesEvent event,
    Emitter<DirectMessageState> emit,
  ) async {
    if (state is! DirectMessageLoadedState) return;
    final current = state as DirectMessageLoadedState;
    final conversationId = _conversationId;
    if (conversationId == null || !current.hasMore || current.isLoadingMore) return;

    emit(current.copyWith(isLoadingMore: true));
    try {
      final result = await _repo.fetchMessages(
        conversationId: conversationId,
        cursor: current.cursor,
      );
      emit(
        current.copyWith(
          items: [...current.items, ...result.items],
          cursor: result.nextCursor,
          hasMore: result.hasMorePage,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _processSendText(
    SendTextMessageEvent event,
    Emitter<DirectMessageState> emit,
  ) async {
    if (state is! DirectMessageLoadedState) return;
    final localId = _newLocalId();
    _emitPending(
      emit,
      localId,
      PendingSend(
        phase: SendPhase.sendingMessage,
        content: event.content,
        replyToId: event.replyToId,
      ),
    );
    try {
      final conversationId = await _ensureConversationId();
      final message = await _repo.sendMessage(
        conversationId: conversationId,
        message: CreateMessageModel(
          type: MessageType.text,
          content: event.content,
          replyToId: event.replyToId,
          mentionedUserIds: event.mentionedUserIds,
        ),
      );
      _resolvePending(emit, localId, message);
    } on AppException catch (e) {
      _failPending(emit, localId, e.message);
    }
  }

  Future<void> _processSendAttachment(
    SendAttachmentMessageEvent event,
    Emitter<DirectMessageState> emit,
  ) async {
    if (state is! DirectMessageLoadedState) return;
    final localId = _newLocalId();
    final cancelToken = CancelToken();
    _cancelTokens[localId] = cancelToken;

    _emitPending(
      emit,
      localId,
      PendingSend(
        phase: SendPhase.uploading,
        attachment: event.attachment,
        content: event.content,
        replyToId: event.replyToId,
      ),
    );
    try {
      final conversationId = await _ensureConversationId();
      final auth = await _repo.getUploadAuth(
        conversationId: conversationId,
        type: event.attachment.messageType,
      );
      final uploadResult = await _cloudinary.upload(
        auth: auth,
        bytes: event.attachment.bytes,
        fileName: event.attachment.fileName,
        cancelToken: cancelToken,
        onProgress: (progress) => _updateProgress(emit, localId, progress),
      );
      _updatePhase(emit, localId, SendPhase.sendingMessage);
      final message = await _repo.sendMessage(
        conversationId: conversationId,
        message: CreateMessageModel(
          type: event.attachment.messageType,
          content: event.content,
          replyToId: event.replyToId,
          durationSeconds: event.attachment.durationSeconds,
          fileUrl: uploadResult.secureUrl,
          fileName: event.attachment.fileName,
          fileSize: uploadResult.bytes,
          fileResourceType: uploadResult.resourceType,
          fileFormat: uploadResult.format,
        ),
      );
      _resolvePending(emit, localId, message);
    } on AppException catch (e) {
      _failPending(emit, localId, e.message);
    } finally {
      _cancelTokens.remove(localId);
    }
  }

  Future<void> _processRetry(
    RetrySendMessageEvent event,
    Emitter<DirectMessageState> emit,
  ) async {
    if (state is! DirectMessageLoadedState) return;
    final current = state as DirectMessageLoadedState;
    final pending = current.pendingSends[event.localId];
    if (pending == null) return;

    // Drop the failed entry and re-dispatch through the normal send path
    // with a fresh localId, rather than duplicating that logic here.
    emit(
      current.copyWith(
        pendingSends: {...current.pendingSends}..remove(event.localId),
      ),
    );
    if (pending.attachment != null) {
      add(
        SendAttachmentMessageEvent(
          attachment: pending.attachment!,
          content: pending.content,
          replyToId: pending.replyToId,
        ),
      );
    } else if (pending.content != null) {
      add(
        SendTextMessageEvent(
          content: pending.content!,
          replyToId: pending.replyToId,
        ),
      );
    }
  }

  Future<void> _processCancel(
    CancelSendMessageEvent event,
    Emitter<DirectMessageState> emit,
  ) async {
    _cancelTokens[event.localId]?.cancel();
    _cancelTokens.remove(event.localId);
    if (state is! DirectMessageLoadedState) return;
    final current = state as DirectMessageLoadedState;
    emit(
      current.copyWith(
        pendingSends: {...current.pendingSends}..remove(event.localId),
      ),
    );
  }

  void _emitPending(
    Emitter<DirectMessageState> emit,
    String localId,
    PendingSend pending,
  ) {
    final current = state as DirectMessageLoadedState;
    emit(
      current.copyWith(
        pendingSends: {...current.pendingSends, localId: pending},
      ),
    );
  }

  void _updateProgress(
    Emitter<DirectMessageState> emit,
    String localId,
    double progress,
  ) {
    if (state is! DirectMessageLoadedState) return;
    final current = state as DirectMessageLoadedState;
    final pending = current.pendingSends[localId];
    if (pending == null) return;
    emit(
      current.copyWith(
        pendingSends: {
          ...current.pendingSends,
          localId: pending.copyWith(progress: progress),
        },
      ),
    );
  }

  void _updatePhase(
    Emitter<DirectMessageState> emit,
    String localId,
    SendPhase phase,
  ) {
    if (state is! DirectMessageLoadedState) return;
    final current = state as DirectMessageLoadedState;
    final pending = current.pendingSends[localId];
    if (pending == null) return;
    emit(
      current.copyWith(
        pendingSends: {
          ...current.pendingSends,
          localId: pending.copyWith(phase: phase),
        },
      ),
    );
  }

  void _resolvePending(
    Emitter<DirectMessageState> emit,
    String localId,
    MessageModel message,
  ) {
    if (state is! DirectMessageLoadedState) return;
    final current = state as DirectMessageLoadedState;
    final pendingSends = {...current.pendingSends}..remove(localId);
    emit(
      current.copyWith(items: [message, ...current.items], pendingSends: pendingSends),
    );
  }

  void _failPending(
    Emitter<DirectMessageState> emit,
    String localId,
    String errorMessage,
  ) {
    if (state is! DirectMessageLoadedState) return;
    final current = state as DirectMessageLoadedState;
    final pending = current.pendingSends[localId];
    if (pending == null) return;
    emit(
      current.copyWith(
        pendingSends: {
          ...current.pendingSends,
          localId: pending.copyWith(
            phase: SendPhase.failed,
            errorMessage: errorMessage,
          ),
        },
      ),
    );
  }
}
