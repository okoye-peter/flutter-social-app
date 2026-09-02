part of 'comment_bloc.dart';

sealed class CommentState extends Equatable {
  const CommentState();

  @override
  List<Object?> get props => [];
}

final class CommentInitialState extends CommentState {}

/// First-page-only loading — once a page has loaded, use
/// [CommentLoadedState.isSubmitting]/[isLoadingMore] instead of
/// transitioning away from it, so an in-flight or failed action never
/// hides the comments already on screen.
final class CommentLoadingState extends CommentState {}

/// First-page-only failure — a create/like/delete/load-more failure is
/// carried on [CommentLoadedState] instead (see above).
final class CommentErrorState extends CommentState {
  const CommentErrorState({required this.message});

  final String message;

  @override
  List<String> get props => [message];
}

final class CommentLoadedState extends CommentState {
  const CommentLoadedState({
    required this.comments,
    required this.hasMorePage,
    this.nextCursor,
    this.isLoadingMore = false,
    this.isSubmitting = false,
    this.submitError,
    this.repliesByParentId = const {},
  });

  final List<CommentModel> comments;
  final bool hasMorePage;
  final String? nextCursor;

  final bool isLoadingMore;

  final bool isSubmitting;
  final String? submitError;

  final Map<String, PaginateDataModel<CommentModel>> repliesByParentId;

  @override
  List<Object?> get props => [
    comments,
    hasMorePage,
    nextCursor,
    isLoadingMore,
    isSubmitting,
    submitError,
    repliesByParentId,
  ];
}