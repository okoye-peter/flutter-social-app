import 'package:flutter/material.dart';

/// Pill-shaped search field shared by the chat list and new-chat screens —
/// visually matches [SearchScreen]'s inline search bar but theme-aware
/// (uses [ColorScheme] instead of hardcoded greys) so it holds up in dark
/// mode too.
class ChatSearch extends StatelessWidget {
  const ChatSearch({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search',
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                child: Icon(Icons.cancel_rounded, size: 18, color: colorScheme.onSurfaceVariant),
              );
            },
          ),
        ],
      ),
    );
  }
}
