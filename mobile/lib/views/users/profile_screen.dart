import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/utils/formatters.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/viewmodels/profile/profile_bloc.dart';
import 'package:social_app/views/users/widgets/profile_header.dart';
import 'package:social_app/views/users/widgets/profile_media_grid.dart';

const _brandColor = Color(0xFF0793F1);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.userId, this.initialUser});

  final String userId;
  final UserModel? initialUser;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final ProfileBloc _bloc = ProfileBloc();
  late final TabController _tabController = TabController(length: 4, vsync: this)
    ..addListener(_onTabChanged);

  @override
  void initState() {
    super.initState();
    _bloc.add(ProfileLoadRequested(userId: widget.userId, initialUser: widget.initialUser));
    // TabController's listener never fires for the already-selected tab 0
    // on first build, so it needs an explicit kick alongside the load.
    _bloc.add(const ProfileTabRequested(tab: ProfileMediaType.post));
  }

  void _onTabChanged() {
    // Fires once as the outgoing tab animates away and again as the
    // incoming tab settles — only act on settle.
    if (_tabController.indexIsChanging) return;
    _bloc.add(ProfileTabRequested(tab: ProfileMediaType.values[_tabController.index]));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              elevation: 0,
              scrolledUnderElevation: 0.5,
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.onSurface,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Text(
                state is ProfileLoadedState ? state.user.username : '',
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
            ),
            body: switch (state) {
              ProfileInitialState() || ProfileLoadingState() => const Center(
                child: CircularProgressIndicator(),
              ),
              ProfileErrorState() => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.error),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _bloc.add(
                          ProfileLoadRequested(userId: widget.userId, initialUser: widget.initialUser),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              ProfileLoadedState() => _ProfileBody(
                state: state,
                colorScheme: colorScheme,
                tabController: _tabController,
              ),
            },
          );
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.state,
    required this.colorScheme,
    required this.tabController,
  });

  final ProfileLoadedState state;
  final ColorScheme colorScheme;
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    final user = state.user;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: ProfileHeader(
              colorScheme: colorScheme,
              avatarUrl: user.image,
              name: user.name,
              username: user.username,
              bio: user.aboutMe,
              location: '',
              postCount: user.postsCount,
              followerCount: formatCount(user.followersCount),
              followingCount: formatCount(user.followingCount),
              isOwnProfile: state.isOwnProfile,
              isFollowedByMe: user.isFollowedByMe,
              onFollowToggle: () => context.read<ProfileBloc>().add(const ProfileFollowToggled()),
            ),
          ),
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileTabBarDelegate(colorScheme: colorScheme, controller: tabController),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: tabController,
        children: [
          for (final tab in ProfileMediaType.values) _buildTab(context, tab),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, ProfileMediaType tab) {
    if (state.isBlockedByMe) return const ProfileBlockedTabState();

    final tabState = state.tabs[tab]!;
    return switch (tabState) {
      ProfileTabInitial() || ProfileTabLoading() => const Center(child: CircularProgressIndicator()),
      ProfileTabBlocked() => const ProfileBlockedTabState(),
      ProfileTabError(:final message) => Center(
        child: Text(message, style: TextStyle(color: colorScheme.error)),
      ),
      ProfileTabLoaded(:final items, :final hasMorePage, :final nextCursor) => ProfileMediaGrid(
        type: tab,
        items: items,
        onLoadMore: hasMorePage
            ? () => context.read<ProfileBloc>().add(
                ProfileTabMoreRequested(tab: tab, cursor: nextCursor!),
              )
            : null,
      ),
    };
  }
}

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileTabBarDelegate({required this.colorScheme, required this.controller});

  final ColorScheme colorScheme;
  final TabController controller;

  static const double _height = 46;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: TabBar(
        controller: controller,
        indicatorColor: _brandColor,
        indicatorWeight: 2.4,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: _brandColor,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        tabs: const [
          Tab(icon: Icon(Icons.grid_on_rounded, size: 23)),
          Tab(icon: Icon(Icons.movie_creation_outlined, size: 23)),
          Tab(icon: Icon(Icons.repeat_rounded, size: 23)),
          Tab(icon: Icon(Icons.alternate_email_rounded, size: 23)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileTabBarDelegate oldDelegate) {
    return oldDelegate.colorScheme != colorScheme || oldDelegate.controller != controller;
  }
}
