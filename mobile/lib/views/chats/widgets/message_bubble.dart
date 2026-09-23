import 'package:flutter/material.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/core/utils/formatters.dart';
import 'package:social_app/models/message_model.dart';
import 'package:social_app/views/chats/widgets/message_actions_sheet.dart';
import 'package:social_app/views/chats/widgets/message_media.dart';
import 'package:social_app/views/chats/widgets/swipe_to_reply.dart';

const _brandColor = Color(0xFF0793F1);

/// One message in a conversation thread: the bubble (right-aligned and
/// brand-colored for the caller's own messages, left-aligned and neutral
/// for the other person's) plus a relative timestamp underneath. Image,
/// video and voice-note messages render their actual media, with any
/// caption shown beneath it. A reply shows the quoted message at the top
/// of the bubble, and reactions sit as chips just under it.
///
/// With [onReply]/[onReact] set, long-pressing opens the reactions/reply
/// menu, swiping right replies, and tapping a reaction chip toggles that
/// emoji for the caller.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onReply,
    this.onReact,
    this.replySenderName,
  });

  final MessageModel message;
  final bool isMine;
  final VoidCallback? onReply;
  final ValueChanged<String>? onReact;
  // Overrides the quoted sender's name (e.g. a group member's current
  // name). Falls back to "You" for the caller, then the name the backend
  // sent with the quote.
  final String? replySenderName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final myId = getIt<UserCache>().current?.id;
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
    final isMediaOnly = media is ChatImageContent || media is ChatVideoContent;
    final replyTo = message.replyTo;

    Widget bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      padding: isMediaOnly
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
          if (replyTo != null)
            Padding(
              padding: isMediaOnly ? const EdgeInsets.fromLTRB(4, 4, 4, 6) : const EdgeInsets.only(bottom: 6),
              child: _ReplyQuote(
                senderName: replySenderName ??
                    (replyTo.senderId != null && replyTo.senderId == myId
                        ? 'You'
                        : (replyTo.senderName ?? 'Unknown')),
                summary: replyTo.summary,
                onBrand: isMine,
              ),
            ),
          ?media,
          if (text != null)
            Padding(
              padding: media == null ? EdgeInsets.zero : const EdgeInsets.fromLTRB(10, 6, 10, 4),
              child: Text(text, style: TextStyle(fontSize: 14.5, color: foreground)),
            ),
        ],
      ),
    );

    final onReply = this.onReply;
    final onReact = this.onReact;
    if (onReply != null && onReact != null) {
      bubble = GestureDetector(
        onLongPress: () => showMessageActions(
          context,
          message: message,
          myReaction: message.reactions[myId],
          onReply: onReply,
          onReact: onReact,
        ),
        child: bubble,
      );
    }

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: align,
        children: [
          bubble,
          if (message.reactions.isNotEmpty)
            _ReactionChips(
              reactions: message.reactions,
              myReaction: message.reactions[myId],
              onTap: onReact,
            ),
          const SizedBox(height: 3),
          Text(
            timeAgo(message.createdAt),
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    return onReply == null ? content : SwipeToReply(onReply: onReply, child: content);
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

/// The quoted original inside a reply's bubble.
class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.senderName, required this.summary, required this.onBrand});

  final String senderName;
  final String summary;
  // On the caller's own (brand-colored) bubble, so use white tones.
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = onBrand ? Colors.white : _brandColor;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: onBrand ? Colors.white.withValues(alpha: 0.18) : colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            senderName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
          ),
          const SizedBox(height: 2),
          Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: onBrand ? Colors.white.withValues(alpha: 0.9) : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-emoji counts under a bubble, most popular first. The caller's own
/// reaction is outlined; tapping a chip toggles that emoji for the caller.
class _ReactionChips extends StatelessWidget {
  const _ReactionChips({required this.reactions, required this.myReaction, required this.onTap});

  final Map<String, String> reactions;
  final String? myReaction;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final entry in sorted)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap == null ? null : () => onTap!(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: entry.key == myReaction
                      ? _brandColor.withValues(alpha: 0.15)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: entry.key == myReaction ? _brandColor : colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                child: Text(
                  entry.value > 1 ? '${entry.key} ${entry.value}' : entry.key,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
