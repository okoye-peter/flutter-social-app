class AppRoutes {
  AppRoutes._();

  static const String onboarding = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String registerPhone = '/register/phone';
  static const String registerDetails = '/register/details';
  static const String forgotPassword = '/forgot-password';
  static const String phoneVerification = '/phone-verification';
  static const String emailVerification = '/email-verification';
  static const String feeds = '/feeds';
  static const String createFeeds = '/feeds/create';
  static const String createStory = '/feeds/create-story';
  static const String storyViewer = '/feeds/story-viewer';
  /// Route pattern, for registering the [GoRoute].
  static const String chats = '/chats';
  static const String groups = '/groups';
  static const String settings = '/settings';
  static const String search = '/feeds/search';
  static const String feedDetails = '/feeds/:id';
  // Nested under the feeds shell branch (like feedDetails/search above) so
  // that pushing between a profile and a post's details stays within that
  // branch's own navigator — pushing a nested-shell route from a top-level
  // screen otherwise causes go_router to reconstruct the shell's ancestor
  // chain and collide with the existing '/feeds' page's key.
  static const String profile = '/feeds/profile/:id';

  /// Builds the actual navigable path for a given reel, e.g.
  /// `feedDetailsPath('abc123')` -> `/feeds/abc123`.
  static String feedDetailsPath(String id) => '/feeds/$id';

  /// Builds the actual navigable path for a given user's profile, e.g.
  /// `profilePath('abc123')` -> `/feeds/profile/abc123`.
  static String profilePath(String id) => '/feeds/profile/$id';
}
