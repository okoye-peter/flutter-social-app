import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Circular avatar that renders [source] as a network image when it
/// looks like a URL (starts with "http"), or as initials text
/// otherwise — pass either `user.image` or `user.getInitials`.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.source,
    required this.radius,
    this.backgroundColor = Colors.white24,
    this.textColor = Colors.white,
  });

  final String source;
  final double radius;
  final Color backgroundColor;
  final Color textColor;

  bool get _isImage => source.trim().toLowerCase().startsWith('http');

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: _isImage ? CachedNetworkImageProvider(source) : null,
      child: _isImage
          ? null
          : Text(
              source,
              style: TextStyle(
                fontSize: radius * 0.7,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
    );
  }
}
