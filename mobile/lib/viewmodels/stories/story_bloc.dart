import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/models/create_story_model.dart';
import 'package:social_app/models/story_model.dart';
import 'package:social_app/repositories/story_repository.dart';

part 'story_event.dart';
part 'story_state.dart';

class StoryBloc extends Bloc<StoryEvent, StoryState> {
  StoryBloc() : super(StoryInitialState()) {
    on<LoadStoryEvent>(_processLoadStories, transformer: droppable());
    on<CreateStoryEvent>(_processCreateStory, transformer: droppable());
    // sequential, not droppable — swiping through several stories fires
    // several of these in quick succession, and droppable() would silently
    // discard the view ping for any story reached while the previous
    // request is still in flight.
    on<MarkStoryAsViewedEvent>(
      _processMarkStoryAsViewed,
      transformer: sequential(),
    );
  }

  final StoryRepository _repo = StoryRepository();

  Future<void> _processLoadStories(
    LoadStoryEvent event,
    Emitter<StoryState> emit,
  ) async {
    emit(LoadingStoryState());
    try {
      final result = await _repo.fetchStoriesFeed();
      emit(StoryLoadedState(stories: result));
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to load stories';
      emit(StoryErrorState(message));
    }
  }

  Future<void> _processCreateStory(
    CreateStoryEvent event,
    Emitter<StoryState> emit,
  ) async {
    emit(const CreatingStoryState());
    try {
      await _repo.createStory(event.story);
      emit(LoadedCreateStoryState(story: event.story));
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to create story';
      emit(StoryErrorState(message));
    }
  }

  Future<void> _processMarkStoryAsViewed(
    MarkStoryAsViewedEvent event,
    Emitter<StoryState> emit,
  ) async {
    try {
      await _repo.markStoryViewed(event.story.id);
    } catch (_) {
      // Best-effort view tracking — a failure here shouldn't interrupt
      // story viewing with an error state.
      return;
    }

    final current = state;
    if (current is StoryLoadedState) {
      emit(
        StoryLoadedState(
          stories: [
            for (final group in current.stories)
              group.withStorySeen(event.story.id),
          ],
        ),
      );
    }
  }
}
