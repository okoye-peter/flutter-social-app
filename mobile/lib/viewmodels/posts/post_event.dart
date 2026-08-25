part of 'post_bloc.dart';

sealed class PostEvent extends Equatable {
  const PostEvent();

  @override
  List<Object> get props => [];
}

final class CreatePostEvent extends PostEvent {
  const CreatePostEvent({required this.post});

  final CreatePostModel post;

  @override
  List<Object> get props => [post];
}

final class FetchPostsEvent extends PostEvent {
  const FetchPostsEvent();
}

final class FetchMovePostsEvent extends PostEvent {
  const FetchMovePostsEvent({
    required this.hasMorePage,
    required this.page
  });

  final bool hasMorePage;
  final int page;

  @override
  List<Object> get props => [page, hasMorePage];
}