import 'package:flutter/material.dart';

const _brandColor = Color(0xFF0793F1);

/// The composer bar at the bottom of a conversation thread: an attach
/// icon, a growable text field, and a trailing button that shows a mic
/// icon while empty and switches to send once there's text.
class ChatMessageInputBar extends StatelessWidget {
  const ChatMessageInputBar({
    super.key,
    required this.controller,
    required this.hasText,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool hasText;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(onPressed: () {}, icon: Icon(Icons.add_circle_outline, color: colorScheme.onSurfaceVariant)),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              decoration: const BoxDecoration(color: _brandColor, shape: BoxShape.circle),
              child: IconButton(
                onPressed: hasText ? onSend : null,
                icon: Icon(hasText ? Icons.send_rounded : Icons.mic_none_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
