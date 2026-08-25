import 'package:social_app/models/story_model.dart';

/// Carries the story groups to display and which one to open first
/// through `GoRouterState.extra` into [StoryViewerScreen]. `onStoryViewed`
/// lets the caller report a view back to the backend (e.g.
/// `POST /api/stories/:id/views`) without the screen depending on a
/// repository directly.
class StoryViewerArgs {
  const StoryViewerArgs({
    required this.groups,
    required this.initialGroupIndex,
    this.onStoryViewed,
  });

  final List<StoryGroupModel> groups;
  final int initialGroupIndex;
  final void Function(String storyId)? onStoryViewed;
}
