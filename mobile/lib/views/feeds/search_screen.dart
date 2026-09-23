import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/viewmodels/user_search/user_search_bloc.dart';
import 'package:social_app/views/feeds/widgets/user_search_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final UserSearchBloc _searchBloc = UserSearchBloc();

  Timer? _debounce;

  void _onSearchChanged(String query) {
    _debounce?.cancel(); // cancel whatever was pending
    _debounce = Timer(const Duration(milliseconds: 400), () {
      // this only runs if 400ms pass with no new keystroke
      _searchBloc.add(UserSearchQueryChanged(query));
    });
  }

  @override
  void dispose() {
    _debounce
        ?.cancel(); // don't let a pending timer fire after the widget is gone
    _searchController.dispose();
    _searchBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return BlocProvider.value(
      value: _searchBloc,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: Icon(CupertinoIcons.back, size: 28),
          ),
          title: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              //   border: isDarkMode ? Border.all(color: Color.fromARGB(122, 227, 227, 227)) : null,
              color: isDarkMode
                  ? theme.secondaryHeaderColor.withAlpha(125)
                  : Color.fromARGB(122, 227, 227, 227),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    autofocus: true,
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    keyboardType: TextInputType.text,
                    showCursor: true,
                    onSubmitted: (String searchString) {},
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: BlocBuilder<UserSearchBloc, UserSearchState>(
            builder: (context, state) {
              if (state is UserSearchLoadingState) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is UserSearchErrorState) {
                return Center(
                  child: Text(
                    state.message,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                );
              }
              if (state is UserSearchLoadedState) {
                if (state.users.isEmpty) {
                  return Center(
                    child: Text(
                      'No results found',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemBuilder: (_, int index) {
                    final result = state.users[index];
                    return UserSearchCard(
                      name: result.name,
                      username: result.username,
                      imageUrl: result.image,
                      followersCount: result.followersCount,
                      isFollowing: result.isFollowedByMe,
                      onTap: () => context.push(
                        AppRoutes.profilePath(result.id),
                        extra: result,
                      ),
                      onFollowToggle: () =>
                          _searchBloc.add(UserSearchFollowToggled(result)),
                    );
                  },
                  separatorBuilder: (_, index) => const SizedBox(height: 4),
                  itemCount: state.users.length,
                );
              }
              return _SearchEmptyState(colorScheme: theme.colorScheme);
            },
          ),
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
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
              child: Icon(
                Icons.search_rounded,
                size: 28,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Search for people',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Find friends and creators by name or username.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
