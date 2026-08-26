import 'package:flutter/material.dart';

const brandColor = Color(0xFF0793F1);

/// Pill call-to-action shown over an empty media preview in a composer
/// screen (Create Post, Add to Story), inviting the user to attach media.
class AddMediaBadge extends StatelessWidget {
  const AddMediaBadge({super.key, this.label = 'Add photo/video'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: brandColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.add_photo_alternate_outlined,
            size: 18,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
