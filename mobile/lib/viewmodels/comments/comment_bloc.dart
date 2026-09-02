import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/models/comment_model.dart';
import 'package:social_app/models/create_comment_model.dart';
import 'package:social_app/models/paginate_data_model.dart';
import 'package:social_app/repositories/comment_repository.dart';

part 'comment_event.dart';
part 'comment_state.dart';

class CommentBloc extends Bloc<CommentEvent, CommentState> {
  CommentBloc() : super(CommentInitialState()) {
    on<LoadCommentEvent>(_processLoadComments, transformer: droppable());
    on<LoadMoreCommentsEvent>(
      _processLoadMoreComments,
      transformer: droppable(),
    );
    on<CreateCommentEvent>(_processCreateComment, transformer: droppable());
    on<LoadRepliesEvent>(_processLoadReplies, transformer: droppable());
    on<ToggleCommentLikeStatusEvent>(
      _processToggleCommentLikeStatus,
      transformer: droppable(),
    );
  }

  final CommentRepository _repo = CommentRepository();

  /// Creates [comment] on [postId] and resolves with whether it
  /// succeeded — the backend bumps the post's comment count for both
  /// top-level comments and replies, so a caller (e.g. [ReelsTile]
  /// bumping its own visible count) can react without inspecting the
  /// state stream.
  Future<bool> createComment(String postId, CreateCommentModel comment) {
    final completer = Completer<bool>();
    add(
      CreateCommentEvent(postId: postId, comment: comment, completer: completer),
    );
    return completer.future;
  }

  Future<void> _processLoadComments(
    LoadCommentEvent event,
    Emitter<CommentState> emit,
  ) async {
    emit(CommentLoadingState());
    try {
      final page = await _repo.listComments(postId: event.postId);
      emit(
        CommentLoadedState(
          comments: page.items,
          hasMorePage: page.hasMorePage,
          nextCursor: page.nextCursor,
        ),
      );
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to load comments';
      emit(CommentErrorState(message: message));
    }
  }

  Future<void> _processLoadMoreComments(
    LoadMoreCommentsEvent event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    // Nothing to append onto, or another load is already in flight.
    if (current is! CommentLoadedState || current.isLoadingMore) return;

    emit(
      CommentLoadedState(
        comments: current.comments,
        hasMorePage: current.hasMorePage,
        nextCursor: current.nextCursor,
        isLoadingMore: true,
        repliesByParentId: current.repliesByParentId,
      ),
    );
    try {
      final page = await _repo.listComments(
        postId: event.postId,
        cursor: event.cursor,
      );
      emit(
        CommentLoadedState(
          comments: [...current.comments, ...page.items],
          hasMorePage: page.hasMorePage,
          nextCursor: page.nextCursor,
          repliesByParentId: current.repliesByParentId,
        ),
      );
    } catch (e) {
      // The list itself is still valid — only surface the failure inline
      // (via submitError, the closest thing to a generic banner) and let
      // the user retry, rather than blanking the comments already shown.
      final message = e is AppException
          ? e.message
          : 'Failed to load more comments';
      emit(
        CommentLoadedState(
          comments: current.comments,
          hasMorePage: current.hasMorePage,
          nextCursor: current.nextCursor,
          submitError: message,
          repliesByParentId: current.repliesByParentId,
        ),
      );
    }
  }

  Future<void> _processCreateComment(
    CreateCommentEvent event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    // The create UI shouldn't be reachable before the list has loaded.
    if (current is! CommentLoadedState) {
      event.completer?.complete(false);
      return;
    }

    emit(
      CommentLoadedState(
        comments: current.comments,
        hasMorePage: current.hasMorePage,
        nextCursor: current.nextCursor,
        isSubmitting: true,
        repliesByParentId: current.repliesByParentId,
      ),
    );
    try {
      final comment = await _repo.createComment(
        postId: event.postId,
        comment: event.comment,
      );
      final replyToId = event.comment.replyToId;
      emit(
        replyToId == null
            ? CommentLoadedState(
                comments: [comment, ...current.comments],
                hasMorePage: current.hasMorePage,
                nextCursor: current.nextCursor,
                repliesByParentId: current.repliesByParentId,
              )
            : CommentLoadedState(
                comments: current.comments,
                hasMorePage: current.hasMorePage,
                nextCursor: current.nextCursor,
                repliesByParentId: _withPrependedReply(
                  current.repliesByParentId,
                  replyToId,
                  comment,
                ),
              ),
      );
      event.completer?.complete(true);
    } catch (e) {
      final message = e is AppException
          ? e.message
          : 'Failed to create comment';
      emit(
        CommentLoadedState(
          comments: current.comments,
          hasMorePage: current.hasMorePage,
          nextCursor: current.nextCursor,
          submitError: message,
          repliesByParentId: current.repliesByParentId,
        ),
      );
      event.completer?.complete(false);
    }
  }

  Future<void> _processLoadReplies(
    LoadRepliesEvent event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    if (current is! CommentLoadedState) return;

    try {
      final page = await _repo.getCommentReplies(
        commentId: event.parentId,
        cursor: event.cursor,
      );
      final existing = current.repliesByParentId[event.parentId];
      final merged = event.cursor == null || existing == null
          ? page
          : PaginateDataModel(
              items: [...existing.items, ...page.items],
              nextCursor: page.nextCursor,
            );
      emit(
        CommentLoadedState(
          comments: current.comments,
          hasMorePage: current.hasMorePage,
          nextCursor: current.nextCursor,
          isLoadingMore: current.isLoadingMore,
          isSubmitting: current.isSubmitting,
          repliesByParentId: {
            ...current.repliesByParentId,
            event.parentId: merged,
          },
        ),
      );
    } catch (e) {
      // The comments/other threads are still valid — surface the failure
      // inline rather than blanking everything already loaded.
      final message = e is AppException ? e.message : 'Failed to load replies';
      emit(
        CommentLoadedState(
          comments: current.comments,
          hasMorePage: current.hasMorePage,
          nextCursor: current.nextCursor,
          isLoadingMore: current.isLoadingMore,
          isSubmitting: current.isSubmitting,
          submitError: message,
          repliesByParentId: current.repliesByParentId,
        ),
      );
    }
  }

  /// Prepends [reply] under [parentId] — into its already-loaded page if
  /// one exists, or as a fresh single-item page otherwise (the thread
  /// hasn't been expanded yet, so there's no real pagination state to
  /// merge into).
  Map<String, PaginateDataModel<CommentModel>> _withPrependedReply(
    Map<String, PaginateDataModel<CommentModel>> repliesByParentId,
    String parentId,
    CommentModel reply,
  ) {
    final existing = repliesByParentId[parentId];
    return {
      ...repliesByParentId,
      parentId: PaginateDataModel(
        items: [reply, ...?existing?.items],
        nextCursor: existing?.nextCursor,
      ),
    };
  }

  Future<void> _processToggleCommentLikeStatus(
    ToggleCommentLikeStatusEvent event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    if (current is! CommentLoadedState) return;

    final original = event.comment;
    final optimistic = original.copyWith(
      likedByMe: !original.likedByMe,
      likesCount: original.likedByMe
          ? original.likesCount - 1
          : original.likesCount + 1,
    );
    // Optimistic: flip the heart immediately, reconcile with the server
    // response below, and roll back only if the request actually fails.
    emit(_applyComment(current, optimistic));
    try {
      final result = original.likedByMe
          ? await _repo.unlikeComment(original.id)
          : await _repo.likeComment(original.id);
      emit(
        _applyComment(
          state,
          optimistic.copyWith(likesCount: result.likesCount),
        ),
      );
    } on AppException {
      emit(_applyComment(state, original));
    }
  }

  Future<void> _processUpdateComment() async {
    try {
      
    } catch (e) {
      
    }
  }

  /// Replaces [updated] into [current] by id — into the top-level
  /// [CommentLoadedState.comments] when [updated] isn't a reply
  /// (`replyToId == null`), otherwise directly into its parent's entry
  /// in [CommentLoadedState.repliesByParentId]. A state that isn't
  /// [CommentLoadedState], or a reply whose parent thread hasn't been
  /// loaded, is returned unchanged.
  CommentState _applyComment(CommentState current, CommentModel updated) {
    if (current is! CommentLoadedState) return current;

    final parentId = updated.replyToId;
    if (parentId == null) {
      return CommentLoadedState(
        comments: [
          for (final comment in current.comments)
            if (comment.id == updated.id) updated else comment,
        ],
        hasMorePage: current.hasMorePage,
        nextCursor: current.nextCursor,
        isLoadingMore: current.isLoadingMore,
        isSubmitting: current.isSubmitting,
        submitError: current.submitError,
        repliesByParentId: current.repliesByParentId,
      );
    }

    final repliesPage = current.repliesByParentId[parentId];
    if (repliesPage == null) return current;

    return CommentLoadedState(
      comments: current.comments,
      hasMorePage: current.hasMorePage,
      nextCursor: current.nextCursor,
      isLoadingMore: current.isLoadingMore,
      isSubmitting: current.isSubmitting,
      submitError: current.submitError,
      repliesByParentId: {
        ...current.repliesByParentId,
        parentId: PaginateDataModel(
          items: [
            for (final reply in repliesPage.items)
              if (reply.id == updated.id) updated else reply,
          ],
          nextCursor: repliesPage.nextCursor,
        ),
      },
    );
  }
}
