import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/helpers/app_toast.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/utils/formatters.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/models/chat_details_args.dart';
import 'package:social_app/models/chat_user_model.dart';
import 'package:social_app/models/message_model.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/viewmodels/user_with_chat_search/user_with_chat_search_bloc.dart';
import 'package:social_app/views/chats/widgets/chat_search.dart';

const _brandColor = Color(0xFF0793F1);

/// The chats inbox: every conversation the caller already has, most
/// recently active first, with a search bar that narrows it down to
/// matching names. Starting a *new* conversation happens via the FAB,
/// which opens the new-chat picker at [AppRoutes.newChat].
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _bloc = UserWithChatSearchBloc();

  Timer? _debounce;
  // The query that produced the bloc's current results — only updated at
  // the moment a query is actually sent to the bloc, so it never mismatches
  // the loaded items/cursor the way a live-typed `_query` could.
  String _dispatchedQuery = '';

  @override
  void initState() {
    super.initState();
    _bloc.add(const UserWithChatSearchQueryChangedEvent());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 200) {
      return;
    }
    final state = _bloc.state;
    if (state is UserWithChatSearchLoadedState &&
        state.hasMorePage &&
        !state.isLoadingMore &&
        state.nextCursor != null) {
      _bloc.add(
        UserWithChatSearchLoadMoreEvent(
          cursor: state.nextCursor!,
          query: _dispatchedQuery,
        ),
      );
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _dispatchedQuery = value;
      _bloc.add(UserWithChatSearchQueryChangedEvent(query: value));
    });
  }

  Future<void> _openNewChat() async {
    final selected = await context.push<UserModel>(AppRoutes.newChat);
    if (selected == null || !mounted) return;
    context.push(
      AppRoutes.chatDetails,
      extra: ChatDetailsArgs(otherUser: selected),
    );
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
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Chats',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ChatSearch(
                controller: _searchController,
                onChanged: _onSearchChanged,
                hintText: 'Search chats',
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openNewChat,
          backgroundColor: _brandColor,
          foregroundColor: Colors.white,
          child: const Icon(Icons.new_label, size: 24),
        ),
        body: SafeArea(
          child: BlocConsumer<UserWithChatSearchBloc, UserWithChatSearchState>(
            listenWhen: (previous, current) =>
                current is UserWithChatSearchLoadedState &&
                current.loadMoreError != null,
            listener: (context, state) {
              final message =
                  (state as UserWithChatSearchLoadedState).loadMoreError!;
              AppToast.error(message);
            },
            builder: (context, state) {
              if (state is UserWithChatSearchErrorState) {
                return _ChatsMessage(
                  icon: Icons.wifi_off_rounded,
                  title: 'Something went wrong',
                  subtitle: state.message,
                  actionLabel: 'Try again',
                  onAction: () => _bloc.add(
                    UserWithChatSearchQueryChangedEvent(
                      query: _dispatchedQuery,
                    ),
                  ),
                );
              }

              if (state is UserWithChatSearchLoadedState) {
                if (state.items.isEmpty) {
                  return _ChatsMessage(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: _dispatchedQuery.isEmpty
                        ? 'No conversations yet'
                        : 'No matches found',
                    subtitle: _dispatchedQuery.isEmpty
                        ? 'Start a new chat and it will show up here.'
                        : 'Try a different name or username.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => _bloc.refreshAndAwait(_dispatchedQuery),
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount:
                        state.items.length + (state.isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 78),
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
                      final chat = state.items[index];
                      return _ChatTile(
                        chat: chat,
                        onTap: () => context.push(
                          AppRoutes.chatDetails,
                          extra: ChatDetailsArgs(
                            otherUser: chat.user,
                            conversationId: chat.conversationId,
                          ),
                        ),
                      );
                    },
                  ),
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

/// One row in the chat list: avatar (with an online dot), name, a preview
/// of the last message, how long ago it was sent, and an unread badge.
class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.onTap});

  final ChatUserModel chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = chat.user;
    final hasUnread = chat.unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    source: user.image.trim().isNotEmpty
                        ? user.image
                        : (user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?'),
                    radius: 27,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    textColor: colorScheme.onSurface,
                  ),
                  if (user.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _lastMessagePreview(chat.lastMessage),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: hasUnread
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    chat.lastMessageAt != null
                        ? timeAgo(chat.lastMessageAt!)
                        : '',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasUnread
                          ? _brandColor
                          : colorScheme.onSurfaceVariant,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _brandColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 20),
                      child: Text(
                        chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
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
      ),
    );
  }
}

/// A short, human label for a chat list preview — text as-is, or a
/// type-appropriate placeholder for media messages that have no text.
String _lastMessagePreview(MessageModel? message) {
  if (message == null) return 'Say hi 👋';
  final content = message.content?.trim();
  if (content != null && content.isNotEmpty) return content;

  return switch (message.type) {
    MessageType.image => '📷 Photo',
    MessageType.video => '🎥 Video',
    MessageType.voiceNote => '🎤 Voice message',
    MessageType.file => '📎 File',
    MessageType.system => 'System message',
    MessageType.text => '',
  };
}

/// Shared empty/error placeholder for the chats screen — centered icon in a
/// soft circle, a title, an optional subtitle, and an optional retry action.
class _ChatsMessage extends StatelessWidget {
  const _ChatsMessage({
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
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
              ),
              child: Icon(icon, size: 28, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
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
