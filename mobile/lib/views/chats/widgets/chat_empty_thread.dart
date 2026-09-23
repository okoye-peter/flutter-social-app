import 'package:flutter/material.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/models/user_model.dart';

/// Placeholder shown in a conversation thread before any messages exist:
/// the other person's avatar/name and a nudge to say hi.
class ChatEmptyThread extends StatelessWidget {
  const ChatEmptyThread({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              source: user.image.trim().isNotEmpty
                  ? user.image
                  : (user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
              radius: 36,
              backgroundColor: colorScheme.surfaceContainerHighest,
              textColor: colorScheme.onSurface,
            ),
            const SizedBox(height: 14),
            Text(
              user.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Say hi 👋 — no messages yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
