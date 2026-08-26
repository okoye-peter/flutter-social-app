import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/views/feeds/widgets/reels_tile.dart';

// TODO: temporary sample used to test reels video playback — replace
// with a real Post.mediaUrl once the feed is wired to the backend.
const _sampleReelVideoUrl =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

class ViewReelDetailsScreen extends StatefulWidget {
  const ViewReelDetailsScreen({super.key, required this.reelId});

  final String reelId;

  @override
  State<ViewReelDetailsScreen> createState() => _ViewReelDetailsScreenState();
}

class _ViewReelDetailsScreenState extends State<ViewReelDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final UserModel? user = getIt<UserCache>().current;

    return Scaffold(
      
      body: SafeArea(

        child: Stack(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: ReelsTile(
                mediaUrl: _sampleReelVideoUrl,
                mediaType: MediaType.video,
                mode: ReelInteractionMode.details,
                avatarUrl: user?.image ?? '',
                username: user?.username ?? 'friend',
                caption: 'Testing reels video playback 🎬',
                soundTitle: '${user?.name ?? 'Friend'} · original audio',
                likeCount: 128,
                repostCount: 100,
                commentCount: 42,
                shareCount: 7,
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: IconButton(onPressed: () => context.pop(), icon: Icon(CupertinoIcons.back, size: 32, color: Colors.white),),
            )
          ],
        )
      ),
    );
  }
}
