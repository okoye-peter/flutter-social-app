import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/user_model.dart';

const _storyItemExtent = 60.0;
const _storyDefaultBorderColor = Color.fromARGB(255, 18, 48, 131);

class FeedsScreen extends StatelessWidget {
  const FeedsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final UserModel? user = getIt<UserCache>().current;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () {},
          icon: Icon(Icons.add, color: theme.tabBarTheme.labelColor, size: 30),
        ),
        title: GestureDetector(
          onTap: () {},
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withAlpha(125)),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.search, size: 20, color: Colors.grey),
                  SizedBox(width: 10),
                  Text(
                    'Search...',
                    style: TextStyle(color: Colors.grey, fontSize: 17),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: Icon(
                  CupertinoIcons.bell,
                  color: theme.tabBarTheme.labelColor,
                  size: 25,
                ),
              ),
              const Positioned(
                top: 13,
                right: 16,
                child: SizedBox(
                  width: 7,
                  height: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: _storyItemExtent,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemExtent: _storyItemExtent,
                itemCount: 15,
                itemBuilder: (_, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _StoryAvatar(
                      user: user,
                      highlightColor: theme.highlightColor,
                      borderColor: index == 0
                          ? Colors.blueAccent
                          : _storyDefaultBorderColor,
                      showAddBadge: index == 0,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({
    required this.user,
    required this.highlightColor,
    required this.borderColor,
    required this.showAddBadge,
  });

  final UserModel? user;
  final Color highlightColor;
  final Color borderColor;
  final bool showAddBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(width: 3, color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: CircleAvatar(
              backgroundImage: user != null && user!.image.trim().isNotEmpty
                  ? CachedNetworkImageProvider(user!.image)
                  : null,
              child: user == null || user!.image.trim().isEmpty
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: highlightColor,
                      ),
                      child: Text(user?.getInitials ?? '?'),
                    )
                  : null,
            ),
          ),
        ),
        if (showAddBadge)
          const Positioned(top: 10, right: 5, child: Icon(Icons.add_circle)),
      ],
    );
  }
}
