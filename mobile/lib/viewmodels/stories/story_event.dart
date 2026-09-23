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
  const LoadStoryEvent({this.completer});

  /// Resolved once this load has settled (loaded or failed) — lets a
  /// caller (e.g. pull-to-refresh) await it instead of firing and forgetting.
  final Completer<void>? completer;
}
