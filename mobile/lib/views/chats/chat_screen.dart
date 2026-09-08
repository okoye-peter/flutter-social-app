import 'package:flutter/material.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/models/message_model.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/views/chats/widgets/chat_empty_thread.dart';
import 'package:social_app/views/chats/widgets/chat_message_input_bar.dart';
import 'package:social_app/views/chats/widgets/message_bubble.dart';

/// A single conversation thread. Purely presentational for now — it keeps
/// its own local [_messages] list and doesn't fetch or send anything yet;
/// that's the seam for the real chat bloc/socket wiring to plug into later.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.otherUser,
    this.conversationId,
  });

  final String? conversationId;
  final UserModel otherUser;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _hasText = false;
  final List<MessageModel> _messages = [];

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    // TODO: send via the real chat bloc/socket once it exists.
    _inputController.clear();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = widget.otherUser;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(
              source: user.image.trim().isNotEmpty
                  ? user.image
                  : (user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
              radius: 18,
              backgroundColor: colorScheme.surfaceContainerHighest,
              textColor: colorScheme.onSurface,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    user.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: user.isOnline ? Colors.green : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.call_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.videocam_outlined)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? ChatEmptyThread(user: user)
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        // messages[0] is assumed oldest-first; reversed list
                        // shows the most recent at the bottom.
                        final message = _messages[_messages.length - 1 - index];
                        final isMine = message.senderId == getIt<UserCache>().current?.id;
                        return MessageBubble(message: message, isMine: isMine);
                      },
                    ),
            ),
            ChatMessageInputBar(
              controller: _inputController,
              hasText: _hasText,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}
