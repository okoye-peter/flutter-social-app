part of 'post_bloc.dart';

sealed class PostState extends Equatable {
  const PostState();

  @override
  List<Object?> get props => [];
}

final class PostInitialState extends PostState {}

final class PostLoadingState extends PostState {
  const PostLoadingState();
}

final class PostLikeStatusUpdatingState extends PostState {
  const PostLikeStatusUpdatingState();
}

final class PostBookMarkStatusUpdatingState extends PostState {
  const PostBookMarkStatusUpdatingState();
}

final class PostRepostStatusUpdatingState extends PostState {
  const PostRepostStatusUpdatingState();
}

final class PostCreatedState extends PostState {
  const PostCreatedState({required this.post});

  final PostModel post;

  @override
  List<Object> get props => [post];
}

final class PostsLoadedState extends PostState {
  const PostsLoadedState({
    required this.items,
    required this.hasMorePage,
    required this.nextCursor,
  });

  final List<FeedItemModel> items;
  final bool hasMorePage;
  final String? nextCursor;

  @override
  List<Object?> get props => [items, hasMorePage, nextCursor];
}

final class PostErrorState extends PostState {
  const PostErrorState({required this.message});

  final String message;

  @override
  List<String> get props => [message];
}

final class PostDetailsLoadedState extends PostState {
  const PostDetailsLoadedState({required this.post});

  final PostModel post;

  @override
  List<Object> get props => [post];
}
