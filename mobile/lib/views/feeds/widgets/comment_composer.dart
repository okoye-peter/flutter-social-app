import 'package:flutter/material.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/models/comment_model.dart';

/// The bottom input bar for [CommentBottomSheet]: reply banner, text field,
/// and send button.
class CommentComposer extends StatelessWidget {
  const CommentComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.replyTo,
    required this.onCancelReply,
    required this.onSubmit,
    required this.isSubmitting,
    required this.bottomInset,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final CommentModel? replyTo;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmit;
  final bool isSubmitting;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = getIt<UserCache>().current;
    final avatarSource = currentUser?.image.isNotEmpty == true
        ? currentUser!.image
        : (currentUser?.getInitials ?? '?');

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant, width: 0.6)),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: 10 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to ${replyTo!.user?.username ?? 'user'}',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  GestureDetector(
                    onTap: onCancelReply,
                    child: Icon(Icons.close, size: 16, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              UserAvatar(
                source: avatarSource,
                radius: 16,
                backgroundColor: colorScheme.surfaceContainerHighest,
                textColor: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText: replyTo != null ? 'Add a reply...' : 'Add a comment...',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final hasText = controller.text.trim().isNotEmpty;
                  if (isSubmitting) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    );
                  }
                  return IconButton(
                    onPressed: hasText ? onSubmit : null,
                    icon: Icon(
                      Icons.send_rounded,
                      color: hasText ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
