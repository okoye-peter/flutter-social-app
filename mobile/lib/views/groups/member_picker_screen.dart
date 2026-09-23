import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/helpers/app_toast.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/viewmodels/user_without_chat_search/user_without_chat_search_bloc.dart';
import 'package:social_app/views/chats/widgets/chat_search.dart';
import 'package:social_app/views/groups/widgets/groups_message.dart';

const _brandColor = Color(0xFF0793F1);

/// Route `extra` for [AppRoutes.groupAddMembers].
class MemberPickerArgs {
  const MemberPickerArgs({
    this.title = 'Add members',
    this.initiallySelected = const [],
    this.excludeIds = const {},
  });

  final String title;
  // Pre-ticked (e.g. re-opening the picker while creating a group).
  final List<UserModel> initiallySelected;
  // Hidden entirely (e.g. people already in the group).
  final Set<String> excludeIds;
}

/// Multi-select over the caller's contacts (people they follow or who
/// follow them). Pops with the selected `List<UserModel>`, or null if
/// dismissed.
class MemberPickerScreen extends StatefulWidget {
  const MemberPickerScreen({super.key, this.args = const MemberPickerArgs()});

  final MemberPickerArgs args;

  @override
  State<MemberPickerScreen> createState() => _MemberPickerScreenState();
}

class _MemberPickerScreenState extends State<MemberPickerScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _bloc = UserWithoutChatSearchBloc();
  // Keyed by id so a selection survives the search results changing.
  late final Map<String, UserModel> _selected = {
    for (final u in widget.args.initiallySelected) u.id: u,
  };

  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _bloc.add(const UserWithoutChatSearchQueryChangedEvent());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 200) {
      return;
    }
    final state = _bloc.state;
    if (state is UserWithoutChatSearchLoadedState &&
        state.hasMorePage &&
        !state.isLoadingMore &&
        state.nextCursor != null) {
      _bloc.add(UserWithoutChatSearchLoadMoreEvent(cursor: state.nextCursor!, query: _query));
    }
  }

  void _onSearchChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _bloc.add(UserWithoutChatSearchQueryChangedEvent(query: value));
    });
  }

  void _toggle(UserModel user) {
    setState(() {
      if (_selected.remove(user.id) == null) _selected[user.id] = user;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.args.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(_selected.values.toList()),
            child: Text(
              _selected.isEmpty ? 'Done' : 'Done (${_selected.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, color: _brandColor),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ChatSearch(
              controller: _searchController,
              onChanged: _onSearchChanged,
              hintText: 'Search people',
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<UserWithoutChatSearchBloc, UserWithoutChatSearchState>(
          bloc: _bloc,
          listenWhen: (_, current) =>
              current is UserWithoutChatSearchLoadedState && current.loadMoreError != null,
          listener: (_, state) =>
              AppToast.error((state as UserWithoutChatSearchLoadedState).loadMoreError!),
          builder: (context, state) {
            if (state is UserWithoutChatSearchErrorState) {
              return GroupsMessage(
                icon: Icons.wifi_off_rounded,
                title: 'Something went wrong',
                subtitle: state.message,
                actionLabel: 'Try again',
                onAction: () => _bloc.add(UserWithoutChatSearchQueryChangedEvent(query: _query)),
              );
            }
            if (state is! UserWithoutChatSearchLoadedState) {
              return const Center(child: CircularProgressIndicator());
            }
            final people = state.items.where((u) => !widget.args.excludeIds.contains(u.id)).toList();
            if (people.isEmpty) {
              return GroupsMessage(
                icon: Icons.person_search_rounded,
                title: _query.isEmpty ? 'No one to add' : 'No matches found',
                subtitle: _query.isEmpty
                    ? 'You can add people you follow or who follow you.'
                    : 'Try a different name or username.',
              );
            }
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: people.length + (state.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= people.length) {
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
                final user = people[index];
                return CheckboxListTile(
                  value: _selected.containsKey(user.id),
                  onChanged: (_) => _toggle(user),
                  activeColor: _brandColor,
                  controlAffinity: ListTileControlAffinity.trailing,
                  secondary: UserAvatar(
                    source: user.image.trim().isNotEmpty
                        ? user.image
                        : (user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
                    radius: 22,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    textColor: colorScheme.onSurface,
                  ),
                  title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
