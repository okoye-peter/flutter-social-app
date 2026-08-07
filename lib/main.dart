import 'package:flutter/material.dart';
import 'package:social_app/views/home/home_screen.dart';
import 'package:adaptive_theme/adaptive_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Color.fromARGB(255, 7, 147, 241),
      ),
      dark: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Color.fromARGB(255, 4, 26, 41),
      ),
      initial: AdaptiveThemeMode.light,
      builder: (theme, darkTheme) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Community Zone',
        theme: theme,
        darkTheme: darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
