import 'package:flutter/material.dart';

const _brandColor = Color(0xFF0793F1);

/// A compact Follow/Following pill button, e.g. for a search result row or
/// any other place too small for the full-size action button on a profile
/// header. Filled brand-blue "Follow" when [isFollowing] is false, outlined
/// "Following" when true.
class FollowButton extends StatelessWidget {
  const FollowButton({super.key, required this.isFollowing, required this.onTap});

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const textStyle = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600);
    const shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(9)));

    return SizedBox(
      height: 32,
      child: isFollowing
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                side: BorderSide(color: colorScheme.outlineVariant),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: shape,
              ),
              child: const Text('Following', style: textStyle),
            )
          : FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: _brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: shape,
              ),
              child: const Text('Follow', style: textStyle),
            ),
    );
  }
}
