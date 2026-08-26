import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:social_app/views/feeds/widgets/reel_media_shimmer.dart';

class ImageBackground extends StatelessWidget {
  const ImageBackground({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => const ReelMediaShimmer(),
        errorWidget: (context, url, error) =>
            const ColoredBox(color: Colors.black),
      ),
    );
  }
}
