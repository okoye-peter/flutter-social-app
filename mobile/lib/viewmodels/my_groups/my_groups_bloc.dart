import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/group_chat_model.dart';
import 'package:social_app/models/message_model.dart';
import 'package:social_app/repositories/group_repository.dart';
import 'package:social_app/services/active_chat_tracker.dart';
import 'package:social_app/services/socket_service.dart';

part 'my_groups_event.dart';
part 'my_groups_state.dart';

/// The "my groups" inbox — every group the caller belongs to, most recently
/// active first. Kept live over the socket: a new message bumps its group
/// to the top, and being added to / removed from a group refreshes the list.
class MyGroupsBloc extends Bloc<MyGroupsEvent, MyGroupsState> {
  MyGroupsBloc() : super(const MyGroupsInitialState()) {
    on<MyGroupsLoadEvent>(_processLoad, transformer: restartable());
    on<MyGroupsLoadMoreEvent>(_processLoadMore, transformer: droppable());
    on<MyGroupsMessageReceivedEvent>(_processMessageReceived, transformer: sequential());
    on<MyGroupsMarkedReadEvent>(_processMarkedRead);
    _socketSub = getIt<SocketService>().events.listen((e) {
      switch (e.name) {
        case 'message:new':
          final raw = e.data['message'];
          if (raw is Map) {
            add(MyGroupsMessageReceivedEvent(
              MessageModel.fromJson(Map<String, dynamic>.from(raw)),
            ));
          }
        case 'conversation:member-added':
        case 'conversation:member-removed':
          // Covers being added to / removed from a group, and member counts
          // changing in one we're already in — a refetch handles all three.
          add(MyGroupsLoadEvent(query: _lastQuery, silent: true));
      }
    });
  }

  final GroupRepository _repo = GroupRepository();
  late final StreamSubscription<SocketEvent> _socketSub;
  String _lastQuery = '';

  @override
  Future<void> close() async {
    await _socketSub.cancel();
    return super.close();
  }

  Future<void> _processLoad(MyGroupsLoadEvent event, Emitter<MyGroupsState> emit) async {
    _lastQuery = event.query;
    if (!event.silent || state is! MyGroupsLoadedState) emit(const MyGroupsLoadingState());
    try {
      final result = await _repo.fetchMyGroups(query: event.query);
      emit(MyGroupsLoadedState(items: result.items, nextCursor: result.nextCursor));
    } catch (e) {
      if (event.silent && state is MyGroupsLoadedState) return;
      emit(MyGroupsErrorState(
        message: e is AppException ? e.message : 'Failed to load your groups',
      ));
    }
  }

  Future<void> _processLoadMore(MyGroupsLoadMoreEvent event, Emitter<MyGroupsState> emit) async {
    final current = state;
    if (current is! MyGroupsLoadedState || current.nextCursor == null) return;
    emit(current.copyWith(isLoadingMore: true));
    try {
      final result = await _repo.fetchMyGroups(query: _lastQuery, cursor: current.nextCursor);
      emit(MyGroupsLoadedState(
        items: [...current.items, ...result.items],
        nextCursor: result.nextCursor,
      ));
    } on AppException catch (e) {
      emit(current.copyWith(isLoadingMore: false, loadMoreError: e.message));
    }
  }

  Future<void> _processMessageReceived(
    MyGroupsMessageReceivedEvent event,
    Emitter<MyGroupsState> emit,
  ) async {
    final current = state;
    if (current is! MyGroupsLoadedState) return;
    final message = event.message;
    final index = current.items.indexWhere((g) => g.conversationId == message.conversationId);
    // Direct-chat messages arrive here too (same socket event) — those are
    // simply not in this list, so ignore them rather than refetching.
    if (index == -1) return;

    final mine = message.senderId == getIt<UserCache>().current?.id;
    final viewing = ActiveChatTracker.conversationId == message.conversationId;
    final row = current.items[index];
    final updated = row.copyWith(
      lastMessage: message,
      lastMessageAt: message.createdAt,
      unreadCount: mine || viewing ? row.unreadCount : row.unreadCount + 1,
    );
    emit(current.copyWith(
      items: [updated, ...current.items.where((g) => g.conversationId != row.conversationId)],
    ));
  }

  void _processMarkedRead(MyGroupsMarkedReadEvent event, Emitter<MyGroupsState> emit) {
    final current = state;
    if (current is! MyGroupsLoadedState) return;
    emit(current.copyWith(
      items: [
        for (final g in current.items)
          g.conversationId == event.conversationId ? g.copyWith(unreadCount: 0) : g,
      ],
    ));
  }
}

extension MyGroupsBlocAwait on MyGroupsBloc {
  /// [MyGroupsLoadEvent] that completes once the fetch has finished — for
  /// [RefreshIndicator], which needs to know when to stop spinning.
  Future<void> refreshAndAwait(String query) async {
    add(MyGroupsLoadEvent(query: query));
    await stream.firstWhere((s) => s is MyGroupsLoadedState || s is MyGroupsErrorState);
  }
}
