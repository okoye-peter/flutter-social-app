import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/repositories/chat_repository.dart';

part 'user_without_chat_search_event.dart';
part 'user_without_chat_search_state.dart';

class UserWithoutChatSearchBloc extends Bloc<UserWithoutChatSearchEvent, UserWithoutChatSearchState> {
  UserWithoutChatSearchBloc() : super(UserWithoutChatSearchInitial()) {
    on<UserWithoutChatSearchQueryChangedEvent>(_processUserWithoutChatSearch, transformer: droppable());
    on<UserWithoutChatSearchLoadMoreEvent>(_processLoadMoreUsersWithoutChat, transformer: droppable());
  }

  final ChatRepository _repo = ChatRepository();

  Future<void> _processUserWithoutChatSearch(
    UserWithoutChatSearchQueryChangedEvent event,
    Emitter<UserWithoutChatSearchState> emit,
  ) async {
    emit(UserWithoutChatSearchLoading());
    try {
      final result = await _repo.searchUsersWithOutChat(query: event.query);
      emit(UserWithoutChatSearchLoadedState(
        items: result.items,
        hasMorePage: result.hasMorePage,
        nextCursor: result.nextCursor,
      ));
    } on AppException catch (e) {
      emit(UserWithoutChatSearchErrorState(message: e.message));
    }
  }

  Future<void> _processLoadMoreUsersWithoutChat(UserWithoutChatSearchLoadMoreEvent event, Emitter<UserWithoutChatSearchState> emit) async {
    if (state is! UserWithoutChatSearchLoadedState) return;

    final currentState = state as UserWithoutChatSearchLoadedState;
    emit(UserWithoutChatSearchLoadedState(
      items: currentState.items,
      hasMorePage: currentState.hasMorePage,
      nextCursor: currentState.nextCursor,
      isLoadingMore: true,
    ));

    try {
      final result = await _repo.searchUsersWithOutChat(query: event.query, cursor: event.cursor);
      emit(UserWithoutChatSearchLoadedState(
        items: [...currentState.items, ...result.items],
        hasMorePage: result.hasMorePage,
        nextCursor: result.nextCursor,
        isLoadingMore: false,
      ));
    } on AppException catch (e) {
      // Keep the already-loaded items on a load-more failure — only the
      // in-flight page failed, not the data already on screen. loadMoreError
      // carries the message for a UI to react to (e.g. a one-off SnackBar)
      // without needing a separate error state that would replace the list.
      emit(UserWithoutChatSearchLoadedState(
        items: currentState.items,
        hasMorePage: currentState.hasMorePage,
        nextCursor: currentState.nextCursor,
        isLoadingMore: false,
        loadMoreError: e.message,
      ));
    }
  }
}