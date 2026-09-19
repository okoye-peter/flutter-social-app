import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/router/routes.dart';
import 'package:social_app/core/storage/token_storage.dart';
import 'package:social_app/firebase_options.dart';
import 'package:social_app/repositories/onboarding_repository.dart';
import 'package:social_app/core/helpers/app_toast.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/services/notification_service.dart';
import 'package:social_app/services/socket_service.dart';
import 'package:social_app/viewmodels/auth/auth_bloc.dart';
import 'package:social_app/viewmodels/call/call_bloc.dart';
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

  final authBloc = AuthBloc();
  if (getIt<TokenStorage>().current != null) {
    authBloc.add(FetchAuthenticatedUserEvent());
  }
  // Was previously never called at all, so no device ever registered an
  // FCM token with the backend regardless of the request path bug fixed
  // alongside this — covers both a fresh login and a restored session.
  authBloc.stream.listen((state) {
    if (state is AuthLoadedState) {
      getIt<NotificationService>().registerToken();
      getIt<SocketService>().connect();
    } else if (state is AuthUnauthenticatedState) {
      getIt<SocketService>().disconnect();
    }
  });

  final router = buildRouter(
    authBloc: authBloc,
    hasSeenOnboarding: getIt<OnboardingStatusNotifier>(),
  );

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
      child: BlocProvider<CallBloc>.value(
        value: getIt<CallBloc>(),
        child: BlocListener<CallBloc, CallState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            switch (state.status) {
              case CallStatus.outgoingRinging:
                router.push(AppRoutes.callOutgoing);
              case CallStatus.incomingRinging:
                router.push(AppRoutes.callIncoming);
              case CallStatus.connecting:
                // Replaces whichever ringing screen is showing — connecting
                // to active is a same-screen state update, not a navigation.
                router.pushReplacement(AppRoutes.callActive);
              case CallStatus.active:
                break;
              case CallStatus.ended:
                // Failure path: CallBloc emits `ended` (with the reason) and
                // then `idle` right after — pop only on idle so the call
                // screen isn't popped twice (the second pop would take the
                // chat screen with it).
                final message = state.errorMessage;
                if (message != null) AppToast.error(message);
              case CallStatus.idle:
                if (router.canPop()) router.pop();
            }
          },
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
        ),
      ),
    );
  }
}
