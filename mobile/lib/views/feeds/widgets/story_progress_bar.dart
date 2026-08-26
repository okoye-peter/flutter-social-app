import 'package:flutter/material.dart';

/// Row of Instagram-style segmented progress bars across the top of the
/// story viewer — one segment per story, filled for past stories, animated
/// for the current one, empty for stories not yet reached.
class StoryProgressBar extends StatelessWidget {
  const StoryProgressBar({
    super.key,
    required this.itemCount,
    required this.currentIndex,
    required this.progress,
  });

  final int itemCount;
  final int currentIndex;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(itemCount, (i) {
        final value = i < currentIndex ? 1.0 : (i == currentIndex ? progress : 0.0);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 2.5,
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white30,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
