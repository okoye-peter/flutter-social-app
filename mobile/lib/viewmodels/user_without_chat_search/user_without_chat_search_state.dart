part of 'user_without_chat_search_bloc.dart';

sealed class UserWithoutChatSearchState extends Equatable {
  const UserWithoutChatSearchState();

  @override
  List<Object?> get props => [];
}

final class UserWithoutChatSearchInitial extends UserWithoutChatSearchState {
  const UserWithoutChatSearchInitial();
}

final class UserWithoutChatSearchLoading extends UserWithoutChatSearchState {
  const UserWithoutChatSearchLoading();
}

final class UserWithoutChatSearchLoadedState extends UserWithoutChatSearchState {
  const UserWithoutChatSearchLoadedState({
    required this.items,
    required this.hasMorePage,
    required this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<UserModel> items;
  final bool hasMorePage;
  final String? nextCursor;
  final bool isLoadingMore;
  // Set only when a load-more attempt fails; items/hasMorePage/nextCursor
  // stay as they were so a failed "load more" never wipes what's already on
  // screen. A UI can listen for this becoming non-null to show a one-off
  // SnackBar/retry affordance without needing a separate error state.
  final String? loadMoreError;

  @override
  List<Object?> get props => [items, hasMorePage, nextCursor, isLoadingMore, loadMoreError];
}

final class UserWithoutChatSearchErrorState extends UserWithoutChatSearchState {
  const UserWithoutChatSearchErrorState({required this.message});

  final String message;

  @override
  List<String> get props => [message];
}