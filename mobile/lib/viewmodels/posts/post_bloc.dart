import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/models/create_post_model.dart';
import 'package:social_app/models/feed_item_model.dart';
import 'package:social_app/models/post_model.dart';
import 'package:social_app/repositories/post_repository.dart';

part 'post_event.dart';
part 'post_state.dart';

class PostBloc extends Bloc<PostEvent, PostState> {
  PostBloc() : super(PostInitialState()) {
    on<CreatePostEvent>(_processCreatePost, transformer: droppable());
    on<FetchPostsEvent>(
      (event, emit) => _processFetchPosts(cursor: null, emit: emit),
      transformer: droppable(),
    );
    on<FetchMovePostsEvent>(
      (event, emit) => _processFetchPosts(cursor: event.cursor, emit: emit),
      transformer: droppable(),
    );
    on<GetPostDetailsEvent>(_processFetchPostDetails, transformer: droppable());
    on<TogglePostLikeStatusEvent>(
      _processTogglePostLikeStatus,
      transformer: droppable(),
    );
    on<TogglePostBookMarkStatusEvent>(
      _processTogglePostBookMarkStatus,
      transformer: droppable(),
    );
    on<TogglePostRepostStatusEvent>(
      _processTogglePostRepostStatus,
      transformer: droppable(),
    );
    on<SyncPostEvent>((event, emit) => emit(_applyPost(state, event.post)));
  }

  final PostRepository _repo = PostRepository();

  /// Toggles [post]'s like status and resolves once the request has
  /// settled (reconciled or rolled back) — lets a caller drive a
  /// per-tap loading indicator without inspecting the state stream.
  Future<void> toggleLike(PostModel post) {
    final completer = Completer<void>();
    add(TogglePostLikeStatusEvent(post: post, completer: completer));
    return completer.future;
  }

  /// Toggles [post]'s like status and resolves once the request has
  /// settled (reconciled or rolled back) — lets a caller drive a
  /// per-tap loading indicator without inspecting the state stream.
  Future<void> toggleBookMark(PostModel post) {
    final completer = Completer<void>();
    add(TogglePostBookMarkStatusEvent(post: post, completer: completer));
    return completer.future;
  }

  /// Toggles [post]'s repost status — pass [comment] for a quote-repost —
  /// and resolves once the request has settled (reconciled or rolled
  /// back), the same way [toggleLike]/[toggleBookMark] do.
  Future<void> toggleRepost(PostModel post, {String? comment}) {
    final completer = Completer<void>();
    add(
      TogglePostRepostStatusEvent(
        post: post,
        comment: comment,
        completer: completer,
      ),
    );
    return completer.future;
  }

  Future<void> _processCreatePost(
    CreatePostEvent event,
    Emitter<PostState> emit,
  ) async {
    emit(PostLoadingState());
    try {
      final newPost = await _repo.createPost(event.post);
      emit(PostCreatedState(post: newPost));
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to create post';
      emit(PostErrorState(message: message));
    }
  }

  Future<void> _processFetchPosts({
    String? cursor,
    required Emitter<PostState> emit,
  }) async {
    final isFirstPage = cursor == null;
    if (isFirstPage) emit(PostLoadingState());
    try {
      final result = await _repo.fetchPosts(cursor: cursor);
      final previousItems = state is PostsLoadedState && !isFirstPage
          ? (state as PostsLoadedState).items
          : <FeedItemModel>[];
      emit(
        PostsLoadedState(
          items: [...previousItems, ...result.items],
          hasMorePage: result.hasMorePage,
          nextCursor: result.nextCursor,
        ),
      );
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to load posts';
      emit(PostErrorState(message: message));
    }
  }

  Future<void> _processFetchPostDetails(
    GetPostDetailsEvent event,
    Emitter emit,
  ) async {
    emit(PostLoadingState());
    try {
      final post = await _repo.getPostDetails(event.postId);
      emit(PostDetailsLoadedState(post: post));
    } catch (e) {
      final message = e is AppException
          ? e.message
          : 'Failed to fetch post details';
      emit(PostErrorState(message: message));
    }
  }

  Future<void> _processTogglePostLikeStatus(
    TogglePostLikeStatusEvent event,
    Emitter<PostState> emit,
  ) async {
    final original = event.post;
    final optimistic = original.copyWith(
      likedByMe: !original.likedByMe,
      likesCount: original.likedByMe
          ? original.likesCount - 1
          : original.likesCount + 1,
    );
    // Optimistic: flip the heart immediately, reconcile with the server
    // response below, and roll back only if the request actually fails.
    emit(_applyPost(state, optimistic));
    try {
      final result = await _repo.togglePostLike(original);
      emit(
        _applyPost(state, optimistic.copyWith(likesCount: result.likesCount)),
      );
    } on AppException {
      emit(_applyPost(state, original));
    } finally {
      event.completer?.complete();
    }
  }

  /// Replaces [updated] into whichever of [current]'s post-bearing states
  /// (list or details) contains a post with a matching id; a state that
  /// doesn't reference this post, or isn't post-bearing, is returned
  /// unchanged.
  PostState _applyPost(PostState current, PostModel updated) {
    return switch (current) {
      PostsLoadedState() => PostsLoadedState(
        items: [
          for (final item in current.items)
            if (item.post.id == updated.id)
              item.copyWithPost(updated)
            else
              item,
        ],
        hasMorePage: current.hasMorePage,
        nextCursor: current.nextCursor,
      ),
      PostDetailsLoadedState() when current.post.id == updated.id =>
        PostDetailsLoadedState(post: updated),
      _ => current,
    };
  }

  Future<void> _processTogglePostBookMarkStatus(
    TogglePostBookMarkStatusEvent event,
    Emitter emit,
  ) async {
    final original = event.post;
    final optimistic = original.copyWith(
      bookmarkedByMe: !original.bookmarkedByMe,
      bookmarksCount: original.bookmarkedByMe
          ? original.bookmarksCount - 1
          : original.bookmarksCount + 1,
    );
    // Optimistic: flip the heart immediately, reconcile with the server
    // response below, and roll back only if the request actually fails.
    emit(_applyPost(state, optimistic));
    try {
      final result = await _repo.togglePostBookMark(original);
      emit(
        _applyPost(
          state,
          optimistic.copyWith(bookmarksCount: result.bookmarksCount),
        ),
      );
    } on AppException {
      emit(_applyPost(state, original));
    } finally {
      event.completer?.complete();
    }
  }

  Future<void> _processTogglePostRepostStatus(
    TogglePostRepostStatusEvent event,
    Emitter emit,
  ) async {
    final original = event.post;
    final optimistic = original.copyWith(
      repostedByMe: !original.repostedByMe,
      repostsCount: original.repostedByMe
          ? original.repostsCount - 1
          : original.repostsCount + 1,
    );
    // Optimistic: flip the repost icon immediately, reconcile with the
    // server response below, and roll back only if the request fails.
    emit(_applyPost(state, optimistic));
    try {
      final result = await _repo.togglePostRepost(
        event.post,
        comment: event.comment,
      );
      emit(
        _applyPost(
          state,
          optimistic.copyWith(repostsCount: result.repostsCount),
        ),
      );
    } on AppException {
      emit(_applyPost(state, original));
    } finally {
      event.completer?.complete();
    }
  }
}
