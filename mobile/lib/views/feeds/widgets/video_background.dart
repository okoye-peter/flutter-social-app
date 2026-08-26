import 'package:flutter/material.dart';
import 'package:social_app/views/feeds/widgets/reel_media_shimmer.dart';
import 'package:video_player/video_player.dart';

class VideoBackground extends StatelessWidget {
  const VideoBackground({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ReelMediaShimmer();
    }

    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}
