part of 'story_bloc.dart';

sealed class StoryEvent extends Equatable {
  const StoryEvent();

  @override
  List<Object> get props => [];
}

final class CreateStoryEvent extends StoryEvent {
  const CreateStoryEvent({required this.story});

  final CreateStoryModel story;

  @override
  List<Object> get props => [story];
}

final class MarkStoryAsViewedEvent extends StoryEvent {
  const MarkStoryAsViewedEvent({required this.story});

  final StoryModel story;

  @override
  List<Object> get props => [story];
}

final class LoadStoryEvent extends StoryEvent {
  const LoadStoryEvent();

}
