part of 'story_bloc.dart';

sealed class StoryState extends Equatable {
  const StoryState();

  @override
  List<Object> get props => [];
}

final class StoryInitialState extends StoryState {
  const StoryInitialState();
}


final class CreatingStoryState extends StoryState {
  const CreatingStoryState();
}

final class LoadedCreateStoryState extends StoryState {
  const LoadedCreateStoryState({required this.story});

  final CreateStoryModel story;

  @override
  List<Object> get props => [story];
}

// fetching story from the backend
final class LoadingStoryState extends StoryState {
  const LoadingStoryState();
}

final class StoryLoadedState extends StoryState {
  const StoryLoadedState({required this.stories});

  final List<StoryGroupModel> stories;

  @override
  List<Object> get props => [stories];
}

final class StoryErrorState extends StoryState {
  const StoryErrorState(this.message);

  final String message;

  @override
  List<String> get props => [message];
}