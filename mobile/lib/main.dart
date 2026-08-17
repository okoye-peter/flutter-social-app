import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/router/routes.dart';
import 'package:social_app/core/storage/token_storage.dart';
import 'package:social_app/firebase_options.dart';
import 'package:social_app/repositories/onboarding_repository.dart';
import 'package:social_app/services/notification_service.dart';
import 'package:social_app/viewmodels/auth/auth_bloc.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await setupLocator();
  await getIt<NotificationService>().init();
  final savedThemeMode = await AdaptiveTheme.getThemeMode();
  final hasSeenOnboarding = await OnboardingRepository().hasSeenOnboarding();

  final authBloc = AuthBloc();
  if (getIt<TokenStorage>().current != null) {
    authBloc.add(FetchAuthenticatedUserEvent());
  }

  final router = buildRouter(authBloc: authBloc, hasSeenOnboarding: hasSeenOnboarding);

  runApp(MyApp(savedThemeMode: savedThemeMode, router: router, authBloc: authBloc));

}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.savedThemeMode, required this.router, required this.authBloc});

  final AdaptiveThemeMode? savedThemeMode;
  final GoRouter router;
  final AuthBloc authBloc;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: Color.fromARGB(255, 7, 147, 241),
    );
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: Color.fromARGB(255, 4, 26, 41),
    );

    return BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: AdaptiveTheme(
        light: lightTheme.copyWith(
          textTheme: GoogleFonts.robotoTextTheme(lightTheme.textTheme),
        ),
        dark: darkTheme.copyWith(
          textTheme: GoogleFonts.robotoTextTheme(darkTheme.textTheme),
        ),
        initial: savedThemeMode ?? AdaptiveThemeMode.light,
        builder: (theme, darkTheme) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Community Zone',
          theme: theme,
          darkTheme: darkTheme,
          routerConfig: router,
        ),
      ),
    );
  }
}
