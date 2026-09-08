import 'package:social_app/models/user_model.dart';

/// Carries the data [ChatScreen] needs through `GoRouterState.extra`.
/// `conversationId` is null when opening a brand-new chat (e.g. from the
/// new-chat picker) where no conversation exists yet.
class ChatDetailsArgs {
  const ChatDetailsArgs({required this.otherUser, this.conversationId});

  final UserModel otherUser;
  final String? conversationId;
}
