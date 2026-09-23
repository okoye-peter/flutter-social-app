part of 'my_groups_bloc.dart';

sealed class MyGroupsState extends Equatable {
  const MyGroupsState();

  @override
  List<Object?> get props => [];
}

final class MyGroupsInitialState extends MyGroupsState {
  const MyGroupsInitialState();
}

final class MyGroupsLoadingState extends MyGroupsState {
  const MyGroupsLoadingState();
}

final class MyGroupsLoadedState extends MyGroupsState {
  const MyGroupsLoadedState({
    required this.items,
    required this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<GroupChatModel> items;
  final String? nextCursor;
  final bool isLoadingMore;
  // One-shot: set only by a failed load-more, for a toast — the loaded
  // items stay on screen.
  final String? loadMoreError;

  bool get hasMorePage => nextCursor != null;

  MyGroupsLoadedState copyWith({
    List<GroupChatModel>? items,
    bool? isLoadingMore,
    String? loadMoreError,
  }) {
    return MyGroupsLoadedState(
      items: items ?? this.items,
      nextCursor: nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: loadMoreError,
    );
  }

  @override
  List<Object?> get props => [items, nextCursor, isLoadingMore, loadMoreError];
}

final class MyGroupsErrorState extends MyGroupsState {
  const MyGroupsErrorState({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
