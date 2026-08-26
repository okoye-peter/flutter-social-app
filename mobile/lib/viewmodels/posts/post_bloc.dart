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
  }

  final PostRepository _repo = PostRepository();

  Future<void> _processCreatePost(
    CreatePostEvent event,
    Emitter<PostState> emit
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
}
