import 'package:flutter/material.dart';
import 'package:social_app/core/enums/app_enums.dart';

const _brandColor = Color(0xFF0793F1);

/// The composer bar at the bottom of a conversation thread: an attach
/// icon, a growable text field, and a trailing button that shows a mic
/// icon while empty, switches to send once there's text, and switches to
/// a stop icon while recording a voice note.
class ChatMessageInputBar extends StatelessWidget {
  const ChatMessageInputBar({
    super.key,
    required this.controller,
    required this.hasText,
    required this.onSendText,
    required this.onPickAttachment,
    required this.isRecording,
    required this.recordingDuration,
    required this.onStartRecording,
    required this.onStopRecording,
    this.focusNode,
    this.replyingToName,
    this.replyingToSummary,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final bool hasText;
  final VoidCallback onSendText;

  /// Opens a picker for MessageType.image or MessageType.video.
  final void Function(MessageType type) onPickAttachment;

  final bool isRecording;
  final Duration recordingDuration;
  final VoidCallback onStartRecording;

  /// discard: true drops the recording instead of sending it.
  final void Function({required bool discard}) onStopRecording;

  final FocusNode? focusNode;

  /// Set while composing a reply — shows a "Replying to …" banner above
  /// the field, dismissed via [onCancelReply].
  final String? replyingToName;
  final String? replyingToSummary;
  final VoidCallback? onCancelReply;

  void _showAttachmentSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onPickAttachment(MessageType.image);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Video'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onPickAttachment(MessageType.video);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingToName != null) _buildReplyBanner(colorScheme),
          _buildComposer(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildReplyBanner(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: _brandColor, width: 3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, size: 18, color: _brandColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $replyingToName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _brandColor,
                  ),
                ),
                if ((replyingToSummary ?? '').isNotEmpty)
                  Text(
                    replyingToSummary!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel reply',
            visualDensity: VisualDensity.compact,
            onPressed: onCancelReply,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: isRecording ? null : () => _showAttachmentSheet(context),
            icon: Icon(
              Icons.add_circle_outline,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: isRecording
                ? Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => onStopRecording(discard: true),
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.fiber_manual_record,
                          color: Colors.red,
                          size: 12,
                        ),
                        const SizedBox(width: 6),
                        Text(_formatDuration(recordingDuration)),
                      ],
                    ),
                  )
                : Container(
                    constraints: const BoxConstraints(
                      minHeight: 40,
                      maxHeight: 120,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
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
            decoration: const BoxDecoration(
              color: _brandColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: hasText
                  ? onSendText
                  : (isRecording
                        ? () => onStopRecording(discard: false)
                        : onStartRecording),
              icon: Icon(
                hasText
                    ? Icons.send_rounded
                    : (isRecording
                          ? Icons.stop_rounded
                          : Icons.mic_none_rounded),
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
