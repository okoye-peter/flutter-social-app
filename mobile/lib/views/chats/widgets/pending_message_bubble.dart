import 'package:flutter/material.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/viewmodels/direct_messages/direct_message_bloc.dart';

const _brandColor = Color(0xFF0793F1);

/// A message still being sent: a local preview (thumbnail for an
/// attachment, or the typed text) plus its current phase — an upload
/// progress ring, a "sending..." indicator, or a retry/cancel affordance
/// on failure. Replaced by a real MessageBubble once DirectMessageBloc
/// resolves it from the POST response.
class PendingMessageBubble extends StatelessWidget {
  const PendingMessageBubble({
    super.key,
    required this.pending,
    required this.onRetry,
    required this.onCancel,
  });

  final PendingSend pending;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  String _attachmentLabel(MessageType type) => switch (type) {
    MessageType.image => '📷 Photo',
    MessageType.video => '🎥 Video',
    MessageType.voiceNote => '🎤 Voice message',
    _ => 'Attachment',
  };

  Widget _trailing() {
    switch (pending.phase) {
      case SendPhase.uploading:
        return SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: pending.progress,
            color: Colors.white,
          ),
        );
      case SendPhase.sendingMessage:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        );
      case SendPhase.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onCancel,
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachment = pending.attachment;
    final caption = pending.content?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _brandColor.withValues(
              alpha: pending.phase == SendPhase.failed ? 0.4 : 0.7,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (attachment != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      attachment.bytes,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.insert_drive_file, color: Colors.white),
                    ),
                  ),
                ),
              Flexible(
                child: Text(
                  caption != null && caption.isNotEmpty
                      ? caption
                      : (attachment != null ? _attachmentLabel(attachment.messageType) : ''),
                  style: const TextStyle(color: Colors.white, fontSize: 14.5),
                ),
              ),
              const SizedBox(width: 8),
              _trailing(),
            ],
          ),
        ),
      ),
    );
  }
}
