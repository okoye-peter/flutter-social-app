part of 'user_with_chat_search_bloc.dart';

sealed class UserWithChatSearchState extends Equatable {
  const UserWithChatSearchState();

  @override
  List<Object?> get props => [];
}

final class UserWithChatSearchInitial extends UserWithChatSearchState {
  const UserWithChatSearchInitial();
}

final class UserWithChatSearchLoading extends UserWithChatSearchState {
  const UserWithChatSearchLoading();
}

final class UserWithChatSearchLoadedState extends UserWithChatSearchState {
  const UserWithChatSearchLoadedState({
    required this.items,
    required this.hasMorePage,
    required this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<ChatUserModel> items;
  final bool hasMorePage;
  final String? nextCursor;
  final bool isLoadingMore;
  final String? loadMoreError;

  @override
  List<Object?> get props => [items, hasMorePage, nextCursor, isLoadingMore, loadMoreError];

}

final class UserWithChatSearchErrorState extends UserWithChatSearchState {
  const UserWithChatSearchErrorState({required this.message});

  final String message;

  @override
  List<String> get props => [message];
}
