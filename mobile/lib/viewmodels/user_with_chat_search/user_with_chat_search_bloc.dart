import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/models/chat_user_model.dart';
import 'package:social_app/repositories/chat_repository.dart';

part 'user_with_chat_search_event.dart';
part 'user_with_chat_search_state.dart';

class UserWithChatSearchBloc extends Bloc<UserWithChatSearchEvent, UserWithChatSearchState> {
  UserWithChatSearchBloc() : super(UserWithChatSearchInitial()) {
    on<UserWithChatSearchQueryChangedEvent>(_processUserWithChatSearch, transformer: droppable());
    on<UserWithChatSearchLoadMoreEvent>(_processLoadMoreUsersWithChat, transformer: droppable());
  }

  final ChatRepository _repo = ChatRepository();

  Future<void> _processUserWithChatSearch(
    UserWithChatSearchQueryChangedEvent event,
    Emitter<UserWithChatSearchState> emit,
  ) async {
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
