import 'package:flutter/material.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/utils/formatters.dart';
import 'package:social_app/models/message_model.dart';
import 'package:social_app/views/chats/widgets/message_media.dart';

const _brandColor = Color(0xFF0793F1);

/// One message in a conversation thread: the bubble (right-aligned and
/// brand-colored for the caller's own messages, left-aligned and neutral
/// for the other person's) plus a relative timestamp underneath. Image,
/// video and voice-note messages render their actual media, with any
/// caption shown beneath it.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.isMine});

  final MessageModel message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final foreground = isMine ? Colors.white : colorScheme.onSurface;
    final url = message.fileUrl;
    final caption = message.content?.trim();
    final hasCaption = caption != null && caption.isNotEmpty;

    final Widget? media = url == null
        ? null
        : switch (message.type) {
            MessageType.image => ChatImageContent(url: url),
            MessageType.video => ChatVideoContent(url: url),
            MessageType.voiceNote => ChatVoiceNoteContent(
              url: url,
              durationSeconds: message.duration,
              foreground: foreground,
            ),
            _ => null,
          };

    final text = hasCaption ? caption : (media == null ? _fallbackText(message) : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: media is ChatImageContent || media is ChatVideoContent
                ? const EdgeInsets.all(4)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isMine ? _brandColor : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ?media,
                if (text != null)
                  Padding(
                    padding: media == null
                        ? EdgeInsets.zero
                        : const EdgeInsets.fromLTRB(10, 6, 10, 4),
                    child: Text(
                      text,
                      style: TextStyle(fontSize: 14.5, color: foreground),
                    ),
                  ),
              ],
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

  // Shown only when there's no caption and no renderable media (e.g. a
  // system message, or a media message whose file URL is missing).
  String _fallbackText(MessageModel message) {
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
