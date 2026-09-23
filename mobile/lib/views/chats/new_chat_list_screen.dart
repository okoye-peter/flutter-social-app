import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/helpers/app_toast.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/viewmodels/user_without_chat_search/user_without_chat_search_bloc.dart';
import 'package:social_app/views/chats/widgets/chat_search.dart';

const _brandColor = Color(0xFF0793F1);

/// Picker for starting a new chat: everyone the caller follows or is
/// followed by, searchable by name/username. Tapping a row pops this
/// screen with the selected [UserModel] — the caller (see
/// [ChatListScreen._openNewChat]) reads it from `context.push`'s result.
class NewChatListScreen extends StatefulWidget {
  const NewChatListScreen({super.key});

  @override
  State<NewChatListScreen> createState() => _NewChatListScreenState();
}

class _NewChatListScreenState extends State<NewChatListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _bloc = UserWithoutChatSearchBloc();

  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _bloc.add(const UserWithoutChatSearchQueryChangedEvent());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 200) {
      return;
    }
    final state = _bloc.state;
    if (state is UserWithoutChatSearchLoadedState &&
        state.hasMorePage &&
        !state.isLoadingMore &&
        state.nextCursor != null) {
      _bloc.add(UserWithoutChatSearchLoadMoreEvent(
        cursor: state.nextCursor!,
        query: _query,
      ));
    }
  }

  void _onSearchChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _bloc.add(UserWithoutChatSearchQueryChangedEvent(query: value));
    });
  }

  void _onTap(UserModel user) => context.pop(user);

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
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'New chat',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ChatSearch(
                controller: _searchController,
                onChanged: _onSearchChanged,
                hintText: 'Search people',
                autofocus: true,
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: BlocConsumer<UserWithoutChatSearchBloc, UserWithoutChatSearchState>(
            listenWhen: (previous, current) =>
                current is UserWithoutChatSearchLoadedState && current.loadMoreError != null,
            listener: (context, state) {
              final message = (state as UserWithoutChatSearchLoadedState).loadMoreError!;
              AppToast.error(message);
              // ScaffoldMessenger.of(context)
              //   ..hideCurrentSnackBar()
              //   ..showSnackBar(SnackBar(content: Text(message)));
            },
            builder: (context, state) {
              if (state is UserWithoutChatSearchErrorState) {
                return _ContactsMessage(
                  icon: Icons.wifi_off_rounded,
                  title: 'Something went wrong',
                  subtitle: state.message,
                  actionLabel: 'Try again',
                  onAction: () => _bloc.add(UserWithoutChatSearchQueryChangedEvent(query: _query)),
                );
              }

              if (state is UserWithoutChatSearchLoadedState) {
                if (state.items.isEmpty) {
                  return _ContactsMessage(
                    icon: Icons.person_search_rounded,
                    title: _query.isEmpty ? 'No contacts yet' : 'No matches found',
                    subtitle: _query.isEmpty
                        ? 'Follow people or get followed to see them here.'
                        : 'Try a different name or username.',
                  );
                }

                return ListView.separated(
                  controller: _scrollController,
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
                    final user = state.items[index];
                    return _ContactTile(user: user, onTap: () => _onTap(user));
                  },
                );
              }

              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }
}

/// One row in the new-chat picker: avatar, name, @username, and a small
/// "Follows you" chip when that's true — a quick signal for who's likely
/// to actually reply.
class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.user, required this.onTap});

  final UserModel user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              UserAvatar(
                source: user.image.trim().isNotEmpty
                    ? user.image
                    : (user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
                radius: 24,
                backgroundColor: colorScheme.surfaceContainerHighest,
                textColor: colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (user.followsMe) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Follows you',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared empty/error placeholder for this screen — same shape as
/// [ChatListScreen]'s, kept local since it's only used here.
class _ContactsMessage extends StatelessWidget {
  const _ContactsMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              child: Icon(icon, size: 28, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(backgroundColor: _brandColor),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
