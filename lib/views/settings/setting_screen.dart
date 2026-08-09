import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {

  bool isDarkTheme = false;

  @override
  void initState() {
    super.initState();
    getThemeMode();
  }

  void getThemeMode() async {
    final saveThemeMode = await AdaptiveTheme.getThemeMode();
    if (saveThemeMode == AdaptiveThemeMode.dark) {
      setState(() {
        isDarkTheme = true;
      });
    } else {
      setState(() {
        isDarkTheme = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: SwitchListTile(
          title: const Text('Change Theme'),
          secondary: Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkTheme ? Colors.white : Colors.black,
            ),
            child: Icon(
              isDarkTheme ? Icons.nightlight_rounded : Icons.wb_sunny_rounded,
              color: isDarkTheme ? Colors.black : Colors.white,
            ),
          ),
          value: isDarkTheme,
          onChanged: (bool value) {
            setState(() {
              isDarkTheme = value;
            });
            if (value) {
              AdaptiveTheme.of(context).setDark();
            } else {
              AdaptiveTheme.of(context).setLight();
            }
          },
        ),
      ),
    );
  }
}