import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/chat_user_model.dart';
import 'package:social_app/models/message_model.dart';
import 'package:social_app/repositories/chat_repository.dart';
import 'package:social_app/services/active_chat_tracker.dart';
import 'package:social_app/services/socket_service.dart';

part 'user_with_chat_search_event.dart';
part 'user_with_chat_search_state.dart';

class UserWithChatSearchBloc extends Bloc<UserWithChatSearchEvent, UserWithChatSearchState> {
  UserWithChatSearchBloc() : super(UserWithChatSearchInitial()) {
    on<UserWithChatSearchQueryChangedEvent>(_processUserWithChatSearch, transformer: droppable());
    on<UserWithChatSearchLoadMoreEvent>(_processLoadMoreUsersWithChat, transformer: droppable());
    on<UserWithChatSearchMessageReceivedEvent>(_processMessageReceived, transformer: sequential());
    _socketSub = getIt<SocketService>().events
        // Direct chats only — without this every group message would miss
        // the list below and trigger a full refetch.
        .where((e) => e.name == 'message:new' && e.data['conversationType'] != 'GROUP')
        .listen((e) {
          final raw = e.data['message'];
          if (raw is Map) {
            add(UserWithChatSearchMessageReceivedEvent(
              MessageModel.fromJson(Map<String, dynamic>.from(raw)),
            ));
          }
        });
  }

  late final StreamSubscription<SocketEvent> _socketSub;
  String _lastQuery = '';

  @override
  Future<void> close() async {
    await _socketSub.cancel();
    return super.close();
  }

  Future<void> _processMessageReceived(
    UserWithChatSearchMessageReceivedEvent event,
    Emitter<UserWithChatSearchState> emit,
  ) async {
    final current = state;
    if (current is! UserWithChatSearchLoadedState) return;
    final message = event.message;
    final index = current.items.indexWhere((c) => c.conversationId == message.conversationId);

    // Not in the loaded list (brand-new conversation): refetch so a first
    // message from someone new shows up. Group messages never get here —
    // they're filtered out by conversationType above.
    if (index == -1) {
      try {
        final result = await _repo.searchUsersWithChat(query: _lastQuery);
        emit(UserWithChatSearchLoadedState(
          items: result.items,
          hasMorePage: result.hasMorePage,
          nextCursor: result.nextCursor,
        ));
      } catch (_) {}
      return;
    }

    final mine = message.senderId == getIt<UserCache>().current?.id;
    final viewing = ActiveChatTracker.conversationId == message.conversationId;
    final row = current.items[index];
    final updated = row.copyWith(
      lastMessage: message,
      lastMessageAt: message.createdAt,
      unreadCount: mine || viewing ? row.unreadCount : row.unreadCount + 1,
    );
    final items = [updated, ...current.items.where((c) => c != row)];
    emit(UserWithChatSearchLoadedState(
      items: items,
      hasMorePage: current.hasMorePage,
      nextCursor: current.nextCursor,
      isLoadingMore: current.isLoadingMore,
      loadMoreError: current.loadMoreError,
    ));
  }

  final ChatRepository _repo = ChatRepository();

  Future<void> _processUserWithChatSearch(
    UserWithChatSearchQueryChangedEvent event,
    Emitter<UserWithChatSearchState> emit,
  ) async {
    _lastQuery = event.query;
    emit(UserWithChatSearchLoading());
    try {
      final result = await _repo.searchUsersWithChat(query: event.query);
      emit(UserWithChatSearchLoadedState(
        items: result.items,
        hasMorePage: result.hasMorePage,
        nextCursor: result.nextCursor,
      ));
    } catch (e) {
      emit(UserWithChatSearchErrorState(message: 'User search failed'));
    }
  }

  Future<void> _processLoadMoreUsersWithChat(UserWithChatSearchLoadMoreEvent event, Emitter<UserWithChatSearchState> emit) async {
    if (state is! UserWithChatSearchLoadedState) return;

    final currentState = state as UserWithChatSearchLoadedState;
    emit(UserWithChatSearchLoadedState(
      items: currentState.items,
      hasMorePage: currentState.hasMorePage,
      nextCursor: currentState.nextCursor,
      isLoadingMore: true,
    ));

    try {
      final result = await _repo.searchUsersWithChat(query: event.query, cursor: event.cursor);
      emit(UserWithChatSearchLoadedState(
        items: [...currentState.items, ...result.items],
        hasMorePage: result.hasMorePage,
        nextCursor: result.nextCursor,
        isLoadingMore: false,
      ));
    } on AppException catch (e) {
      emit(UserWithChatSearchLoadedState(
        items: currentState.items,
        hasMorePage: currentState.hasMorePage,
        nextCursor: currentState.nextCursor,
        isLoadingMore: false,
        loadMoreError: e.message,
      ));
    }
  }
}

extension UserWithChatSearchBlocAwait on UserWithChatSearchBloc {
  /// Dispatches [UserWithChatSearchQueryChangedEvent] and waits for the
  /// resulting Loaded/Error state. `add` alone is fire-and-forget, which
  /// isn't enough for a caller (e.g. [RefreshIndicator]) that needs to know
  /// when the fetch has actually finished.
  Future<void> refreshAndAwait(String query) async {
    add(UserWithChatSearchQueryChangedEvent(query: query));
    await stream.firstWhere(
      (state) => state is UserWithChatSearchLoadedState || state is UserWithChatSearchErrorState,
    );
  }
}
