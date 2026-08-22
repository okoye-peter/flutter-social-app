import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/router/app_routes.dart';

/// The tab-root paths — [NavigationBar] shows only when the current
/// route is one of these; any nested route (e.g. a reel's detail page)
/// hides it for a full-screen presentation.
const _tabRootPaths = {
  AppRoutes.feeds,
  AppRoutes.chats,
  AppRoutes.groups,
  AppRoutes.settings,
};

/// Shell for the bottom-tab section of the app (Feeds, Chats, Groups,
/// Settings). Each tab is a [StatefulShellRoute] branch with its own
/// navigation stack and state kept alive in the background, so switching
/// tabs swaps the visible branch instantly instead of pushing a new page.
class HomeScaffold extends StatefulWidget {
  const HomeScaffold({
    super.key,
    required this.navigationShell,
    required this.currentFullPath,
  });

  final StatefulNavigationShell navigationShell;

  /// The route pattern (e.g. `/feeds` or `/feeds/:id`) currently matched
  /// within the shell, from the enclosing [StatefulShellRoute]'s builder
  /// state — used to hide the tab bar on nested full-screen routes.
  final String? currentFullPath;

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 1,
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late Animation<Offset> _slide = _buildSlide(1);

  Animation<Offset> _buildSlide(int direction) {
    return Tween<Offset>(
      begin: Offset(0.06 * direction, 0),
      end: Offset.zero,
    ).animate(_curved);
  }

  @override
  void didUpdateWidget(covariant HomeScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIndex = oldWidget.navigationShell.currentIndex;
    final newIndex = widget.navigationShell.currentIndex;
    if (oldIndex != newIndex) {
      _slide = _buildSlide(newIndex > oldIndex ? 1 : -1);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showNavBar = _tabRootPaths.contains(widget.currentFullPath);

    return Scaffold(
      body: FadeTransition(
        opacity: _curved,
        child: SlideTransition(position: _slide, child: widget.navigationShell),
      ),
      bottomNavigationBar: showNavBar
          ? NavigationBar(
              selectedIndex: widget.navigationShell.currentIndex,
              onDestinationSelected: widget.navigationShell.goBranch,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dynamic_feed_outlined),
                  selectedIcon: Icon(Icons.dynamic_feed_rounded),
                  label: 'Feeds',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  selectedIcon: Icon(Icons.chat_bubble_rounded),
                  label: 'Chats',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups_rounded),
                  label: 'Groups',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            )
          : null,
    );
  }
}
