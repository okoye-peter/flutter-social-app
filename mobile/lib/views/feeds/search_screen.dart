import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/models/user_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final UserModel? user = getIt<UserCache>().current;
    final isDarkMode = theme.brightness == Brightness.dark;

    final List<UserModel> data = [];

    return Scaffold(
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
                  onChanged: (String searchString) {},
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
        child: _searchController.text.trim().length > 3
            ? ListView.separated(
                itemBuilder: (_, int index) {
                  final result = data[index];
                  return InkWell(
                    onTap: () {},
                    child: Row(
                      children: [
                        UserAvatar(
                          source: result.image.trim().isNotEmpty
                              ? result.image
                              : result.getInitials,
                          radius: 24,
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, index) => const SizedBox(height: 15),
                itemCount: data.length,
              )
            : _SearchEmptyState(colorScheme: theme.colorScheme),
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
