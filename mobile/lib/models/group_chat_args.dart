/// Route `extra` for [AppRoutes.groupChat]. Name/image let the header render
/// immediately; the full member list is fetched by the screen itself.
class GroupChatArgs {
  const GroupChatArgs({
    required this.conversationId,
    required this.name,
    this.image = '',
  });

  final String conversationId;
  final String name;
  final String image;
}
