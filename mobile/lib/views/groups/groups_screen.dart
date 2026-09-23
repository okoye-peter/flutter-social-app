import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/helpers/app_toast.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/core/utils/formatters.dart';
import 'package:social_app/models/conversation_model.dart';
import 'package:social_app/models/group_chat_args.dart';
import 'package:social_app/models/group_chat_model.dart';
import 'package:social_app/models/group_model.dart';
import 'package:social_app/models/message_model.dart';
import 'package:social_app/viewmodels/group_search/group_search_bloc.dart';
import 'package:social_app/viewmodels/my_groups/my_groups_bloc.dart';
import 'package:social_app/views/chats/widgets/chat_search.dart';
import 'package:social_app/views/groups/widgets/group_avatar.dart';
import 'package:social_app/views/groups/widgets/groups_message.dart';

const _brandColor = Color(0xFF0793F1);

/// The Groups tab: "My groups" (every group the caller is in, kept live over
/// the socket) and "Discover" (search for groups to join). The FAB creates
/// a new group.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  // Owned here rather than by each tab so they survive TabBarView
  // disposing an off-screen tab, and so creating/joining a group from
  // either place can refresh "My groups".
  final _myGroupsBloc = MyGroupsBloc()..add(const MyGroupsLoadEvent());
  final _searchBloc = GroupSearchBloc();

  Future<void> _openGroup(String conversationId, String name, String image) async {
    await context.push(
      AppRoutes.groupChat,
      extra: GroupChatArgs(conversationId: conversationId, name: name, image: image),
    );
    // Opening the thread marked it read server-side.
    _myGroupsBloc.add(MyGroupsMarkedReadEvent(conversationId));
  }

  Future<void> _createGroup() async {
    final created = await context.push<ConversationModel>(AppRoutes.groupCreate);
    if (created == null || !mounted) return;
    _myGroupsBloc.add(const MyGroupsLoadEvent(silent: true));
    await _openGroup(created.id, created.name ?? '', created.image ?? '');
  }

  @override
  void dispose() {
    _myGroupsBloc.close();
    _searchBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Groups',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          bottom: const TabBar(
            indicatorColor: _brandColor,
            labelColor: _brandColor,
            tabs: [Tab(text: 'My groups'), Tab(text: 'Discover')],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _createGroup,
          backgroundColor: _brandColor,
          foregroundColor: Colors.white,
          tooltip: 'New group',
          child: const Icon(Icons.group_add_rounded),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _MyGroupsTab(bloc: _myGroupsBloc, onOpen: _openGroup, onCreate: _createGroup),
              _DiscoverTab(
                bloc: _searchBloc,
                onJoined: (group) {
                  _myGroupsBloc.add(const MyGroupsLoadEvent(silent: true));
                  _openGroup(group.id, group.name, group.image);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyGroupsTab extends StatefulWidget {
  const _MyGroupsTab({required this.bloc, required this.onOpen, required this.onCreate});

  final MyGroupsBloc bloc;
  final Future<void> Function(String conversationId, String name, String image) onOpen;
  final VoidCallback onCreate;

  @override
  State<_MyGroupsTab> createState() => _MyGroupsTabState();
}

class _MyGroupsTabState extends State<_MyGroupsTab> with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 200) {
      return;
    }
    final state = widget.bloc.state;
    if (state is MyGroupsLoadedState && state.hasMorePage && !state.isLoadingMore) {
      widget.bloc.add(const MyGroupsLoadMoreEvent());
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _query = value.trim();
      widget.bloc.add(MyGroupsLoadEvent(query: _query));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: ChatSearch(
            controller: _searchController,
            onChanged: _onSearchChanged,
            hintText: 'Search your groups',
          ),
        ),
        Expanded(
          child: BlocConsumer<MyGroupsBloc, MyGroupsState>(
            bloc: widget.bloc,
            listenWhen: (_, current) => current is MyGroupsLoadedState && current.loadMoreError != null,
            listener: (_, state) => AppToast.error((state as MyGroupsLoadedState).loadMoreError!),
            builder: (context, state) {
              if (state is MyGroupsErrorState) {
                return GroupsMessage(
                  icon: Icons.wifi_off_rounded,
                  title: 'Something went wrong',
                  subtitle: state.message,
                  actionLabel: 'Try again',
                  onAction: () => widget.bloc.add(MyGroupsLoadEvent(query: _query)),
                );
              }
              if (state is! MyGroupsLoadedState) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.items.isEmpty) {
                return _query.isEmpty
                    ? GroupsMessage(
                        icon: Icons.groups_outlined,
                        title: 'No groups yet',
                        subtitle: 'Create a group, or find one to join in Discover.',
                        actionLabel: 'Create a group',
                        onAction: widget.onCreate,
                      )
                    : const GroupsMessage(
                        icon: Icons.search_off_rounded,
                        title: 'No matches found',
                        subtitle: 'Try a different group name.',
                      );
              }
              return RefreshIndicator(
                onRefresh: () => widget.bloc.refreshAndAwait(_query),
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 78),
                  itemBuilder: (context, index) {
                    if (index >= state.items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final group = state.items[index];
                    return _GroupTile(
                      group: group,
                      onTap: () => widget.onOpen(group.conversationId, group.name, group.image),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One "my groups" row: photo, name, last-message preview, time, unread.
class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.onTap});

  final GroupChatModel group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasUnread = group.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            GroupAvatar(image: group.image, radius: 27),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (group.visibility == ConversationVisibility.private) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.lock_outline_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _preview(group.lastMessage),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                      color: hasUnread ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  group.lastMessageAt != null ? timeAgo(group.lastMessageAt!) : '',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasUnread ? _brandColor : colorScheme.onSurfaceVariant,
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 6),
                if (hasUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 20),
                    decoration: BoxDecoration(
                      color: _brandColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      group.unreadCount > 99 ? '99+' : '${group.unreadCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _preview(MessageModel? message) {
    if (message == null) return 'No messages yet · say hi 👋';
    final mine = message.senderId != null && message.senderId == getIt<UserCache>().current?.id;
    final content = message.content?.trim();
    final body = (content != null && content.isNotEmpty)
        ? content
        : switch (message.type) {
            MessageType.image => '📷 Photo',
            MessageType.video => '🎥 Video',
            MessageType.voiceNote => '🎤 Voice message',
            MessageType.file => '📎 File',
            MessageType.system || MessageType.text => '',
          };
    return mine ? 'You: $body' : body;
  }
}

class _DiscoverTab extends StatefulWidget {
  const _DiscoverTab({required this.bloc, required this.onJoined});

  final GroupSearchBloc bloc;
  final ValueChanged<GroupModel> onJoined;

  @override
  State<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<_DiscoverTab> with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.bloc.add(GroupSearchQueryChanged(value));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: ChatSearch(
            controller: _searchController,
            onChanged: _onSearchChanged,
            hintText: 'Search groups to join',
          ),
        ),
        Expanded(
          child: BlocConsumer<GroupSearchBloc, GroupSearchState>(
            bloc: widget.bloc,
            listenWhen: (_, current) =>
                current is GroupSearchLoadedState &&
                (current.joined != null || current.notice != null || current.actionError != null),
            listener: (_, state) {
              final s = state as GroupSearchLoadedState;
              if (s.actionError != null) AppToast.error(s.actionError!);
              if (s.notice != null) AppToast.success(s.notice!);
              if (s.joined != null) {
                AppToast.success('You joined ${s.joined!.name}');
                widget.onJoined(s.joined!);
              }
            },
            builder: (context, state) {
              return switch (state) {
                GroupSearchInitialState() => const GroupsMessage(
                  icon: Icons.travel_explore_rounded,
                  title: 'Find a group',
                  subtitle: 'Search by name. Public groups let you in straight away; '
                      'private groups send the admins a request.',
                ),
                GroupSearchLoadingState() => const Center(child: CircularProgressIndicator()),
                GroupSearchErrorState(:final message) => GroupsMessage(
                  icon: Icons.wifi_off_rounded,
                  title: 'Something went wrong',
                  subtitle: message,
                  actionLabel: 'Try again',
                  onAction: () => widget.bloc.add(GroupSearchQueryChanged(_searchController.text)),
                ),
                GroupSearchLoadedState(:final groups) when groups.isEmpty => const GroupsMessage(
                  icon: Icons.search_off_rounded,
                  title: 'No groups found',
                  subtitle: "Try another name — groups you're already in don't show here.",
                ),
                GroupSearchLoadedState(:final groups, :final busyIds) => ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 78),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _DiscoverTile(
                      group: group,
                      busy: busyIds.contains(group.id),
                      onJoin: () => widget.bloc.add(GroupJoinPressed(group)),
                      onCancel: () => widget.bloc.add(GroupJoinCancelPressed(group)),
                    );
                  },
                ),
              };
            },
          ),
        ),
      ],
    );
  }
}

/// A discoverable group: photo, name, public/private + member count, and a
/// Join / Request / Requested button depending on visibility and status.
class _DiscoverTile extends StatelessWidget {
  const _DiscoverTile({
    required this.group,
    required this.busy,
    required this.onJoin,
    required this.onCancel,
  });

  final GroupModel group;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPrivate = group.visibility.toUpperCase() == 'PRIVATE';
    final pending = group.joinStatus == GroupJoinStatus.pending;
    final members = '${group.memberCount} member${group.memberCount == 1 ? '' : 's'}';

    final Widget action;
    if (busy) {
      action = const SizedBox(
        width: 88,
        child: Center(
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    } else if (pending) {
      action = OutlinedButton(onPressed: onCancel, child: const Text('Requested'));
    } else {
      action = FilledButton(
        onPressed: onJoin,
        style: FilledButton.styleFrom(backgroundColor: _brandColor),
        child: Text(isPrivate ? 'Request' : 'Join'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GroupAvatar(image: group.image, radius: 27),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      isPrivate ? Icons.lock_outline_rounded : Icons.public_rounded,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${isPrivate ? 'Private' : 'Public'} · $members',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }
}
