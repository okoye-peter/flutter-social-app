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

  /// Builds the actual navigable path for a given reel, e.g.
  /// `feedDetailsPath('abc123')` -> `/feeds/abc123`.
  static String feedDetailsPath(String id) => '/feeds/$id';
}
