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

final class PostCreatedState extends PostState {
  const PostCreatedState({required this.post});

  final PostModel post;

  @override
  List<Object> get props => [post];
}

final class PostLoadedState extends PostState {
  const PostLoadedState({
    required this.posts,
    required this.hasMorePage,
    required this.nextCursor,
  });

  final List<PostModel> posts;
  final bool hasMorePage;
  final String? nextCursor;

  @override
  List<Object?> get props => [posts, hasMorePage, nextCursor];
}

final class PostErrorState extends PostState {
  const PostErrorState({required this.message});

  final String message;

  @override
  List<String> get props => [message];
}

final class FetchPostDetails extends PostState {
  const FetchPostDetails({required this.post});

  final PostModel post;

  @override
  List<Object> get props => [post];
}
