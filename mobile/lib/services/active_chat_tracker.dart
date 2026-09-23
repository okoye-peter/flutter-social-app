/// The conversation whose thread screen is currently open, if any. Lets the
/// chats inbox skip bumping the unread badge for a message the user is
/// already looking at.
class ActiveChatTracker {
  static String? conversationId;
}
