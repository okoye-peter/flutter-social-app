import 'package:flutter/material.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/utils/formatters.dart';
import 'package:social_app/models/message_model.dart';

const _brandColor = Color(0xFF0793F1);

/// One message in a conversation thread: the bubble (right-aligned and
/// brand-colored for the caller's own messages, left-aligned and neutral
/// for the other person's) plus a relative timestamp underneath.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.isMine});

  final MessageModel message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isMine ? _brandColor : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
            ),
            child: Text(
              _bubbleText(message),
              style: TextStyle(fontSize: 14.5, color: isMine ? Colors.white : colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            timeAgo(message.createdAt),
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _bubbleText(MessageModel message) {
    final content = message.content?.trim();
    if (content != null && content.isNotEmpty) return content;
    return switch (message.type) {
      MessageType.image => '📷 Photo',
      MessageType.video => '🎥 Video',
      MessageType.voiceNote => '🎤 Voice message',
      MessageType.file => '📎 File',
      MessageType.system => 'System message',
      MessageType.text => '',
    };
  }
}
