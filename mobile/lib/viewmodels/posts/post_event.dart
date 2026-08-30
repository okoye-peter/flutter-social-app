part of 'post_bloc.dart';

sealed class PostEvent extends Equatable {
  const PostEvent();

  @override
  List<Object?> get props => [];
}

final class CreatePostEvent extends PostEvent {
  const CreatePostEvent({required this.post});

  final CreatePostModel post;

  @override
  List<Object> get props => [post];
}

final class GetPostDetailsEvent extends PostEvent {
  const GetPostDetailsEvent({required this.postId});

  final String postId;

  @override
  List<String> get props => [postId];
}

final class FetchPostsEvent extends PostEvent {
  const FetchPostsEvent();
}

final class TogglePostLikeStatusEvent extends PostEvent {
  const TogglePostLikeStatusEvent({required this.post, this.completer});

  final PostModel post;

  /// Resolved once this toggle has settled (reconciled or rolled back).
  /// Not part of [props] — a [Completer] has no meaningful equality.
  final Completer<void>? completer;

  @override
  List<Object> get props => [post];
}

final class TogglePostBookMarkStatusEvent extends PostEvent {
  const TogglePostBookMarkStatusEvent({required this.post, this.completer});

  final PostModel post;

  final Completer<void>? completer;

  @override
  List<Object> get props => [post];
}

final class TogglePostRepostStatusEvent extends PostEvent {
  const TogglePostRepostStatusEvent({required this.post, this.completer, this.comment});

  final PostModel post;
  final String? comment;

  final Completer<void>? completer;

  @override
  List<Object?> get props => [post, comment];
}

/// Patches a single post into whatever list/details state is currently
/// held, without hitting the network. Used to reconcile a [PostModel]
/// that changed in a different [PostBloc] instance — e.g. the feed
/// screen's bloc syncing a like toggled on the details screen's bloc.
final class SyncPostEvent extends PostEvent {
  const SyncPostEvent({required this.post});

  final PostModel post;

  @override
  List<Object> get props => [post];
}

final class FetchMovePostsEvent extends PostEvent {
  const FetchMovePostsEvent({required this.cursor});

  final String cursor;

  @override
  List<String> get props => [cursor];
}
