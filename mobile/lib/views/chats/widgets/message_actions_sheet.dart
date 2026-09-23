import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:social_app/core/helpers/app_toast.dart';
import 'package:social_app/models/message_model.dart';

const _brandColor = Color(0xFF0793F1);

/// The quick-reaction emojis offered on a message.
const quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// Long-press menu for a message: a row of quick reactions (the caller's
/// current one highlighted — tapping it again removes it), then Reply and,
/// for messages with text, Copy.
Future<void> showMessageActions(
  BuildContext context, {
  required MessageModel message,
  required String? myReaction,
  required VoidCallback onReply,
  required ValueChanged<String> onReact,
}) {
  HapticFeedback.mediumImpact();
  final text = message.content?.trim() ?? '';
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final emoji in quickReactions)
                    InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onReact(emoji);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: emoji == myReaction
                              ? _brandColor.withValues(alpha: 0.18)
                              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onReply();
              },
            ),
            if (text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy text'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Clipboard.setData(ClipboardData(text: text));
                  AppToast.show('Copied');
                },
              ),
          ],
        ),
      );
    },
  );
}
