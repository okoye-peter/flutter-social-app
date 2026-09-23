part of 'comment_bloc.dart';

sealed class CommentEvent extends Equatable {
  const CommentEvent();

  @override
  List<Object> get props => [];
}

final class LoadCommentEvent extends CommentEvent {
  const LoadCommentEvent({required this.postId});

  final String postId;

  @override
  List<Object> get props => [postId];
}

final class CreateCommentEvent extends CommentEvent {
  const CreateCommentEvent({
    required this.comment,
    required this.postId,
    this.completer,
  });

  final CreateCommentModel comment;
  final String postId;

  /// Resolved with whether the comment was created successfully.
  /// Not part of [props] — a [Completer] has no meaningful equality.
  final Completer<bool>? completer;

  @override
  List<Object> get props => [comment, postId];
}

final class UpdateCommentEvent extends CommentEvent {
  const UpdateCommentEvent({required this.comment,  required this.commentId});

  final CreateCommentModel comment;
  final String commentId;

  @override
  List<Object> get props => [comment, commentId];
}

final class LoadMoreCommentsEvent extends CommentEvent {
  const LoadMoreCommentsEvent({required this.postId, required this.cursor});

  final String postId;
  final String cursor;

  @override
  List<String> get props => [postId, cursor];
}

final class LoadRepliesEvent extends CommentEvent {
  const LoadRepliesEvent({required this.parentId, this.cursor});

  final String parentId;

  final String? cursor;

  @override
  List<Object> get props => [parentId, ?cursor];
}

final class ToggleCommentLikeStatusEvent extends CommentEvent {
  const ToggleCommentLikeStatusEvent({required this.comment});

  final CommentModel comment;

  @override
  List<Object> get props => [comment];
}

final class DeleteCommentEvent extends CommentEvent {
  const DeleteCommentEvent({required this.comment});

  final CommentModel comment;

  @override
  List<Object> get props => [comment];
}
