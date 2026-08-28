import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/models/create_post_model.dart';
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
  }

  final PostRepository _repo = PostRepository();

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
      final previousPosts = state is PostsLoadedState && !isFirstPage
          ? (state as PostsLoadedState).posts
          : <PostModel>[];
      emit(
        PostsLoadedState(
          posts: [...previousPosts, ...result.posts],
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
}
