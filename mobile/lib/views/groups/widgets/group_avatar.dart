import 'package:flutter/material.dart';
import 'package:social_app/core/widgets/user_avatar.dart';

/// A group's photo, or a generic groups icon when it has none.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, required this.image, required this.radius});

  final String? image;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = image?.trim() ?? '';
    if (url.toLowerCase().startsWith('http')) {
      return UserAvatar(
        source: url,
        radius: radius,
        backgroundColor: colorScheme.surfaceContainerHighest,
        textColor: colorScheme.onSurface,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primaryContainer,
      child: Icon(
        Icons.groups_rounded,
        size: radius * 1.1,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }
}
