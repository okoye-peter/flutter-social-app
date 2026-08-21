import 'package:go_router/go_router.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/router/go_router_refresh_stream.dart';
import 'package:social_app/core/widgets/home_screen.dart';
import 'package:social_app/models/registration_draft.dart';
import 'package:social_app/viewmodels/auth/auth_bloc.dart';
import 'package:social_app/views/auth/email_veritication_screen.dart';
import 'package:social_app/views/auth/forgot_password_screen.dart';
import 'package:social_app/views/auth/login_screen.dart';
import 'package:social_app/views/auth/phone_verification_screen.dart';
import 'package:social_app/views/auth/register_details_screen.dart';
import 'package:social_app/views/auth/register_phone_screen.dart';
import 'package:social_app/views/auth/register_screen.dart';
import 'package:social_app/views/chats/chats_screen.dart';
import 'package:social_app/views/feeds/feeds_screen.dart';
import 'package:social_app/views/groups/groups_screen.dart';
import 'package:social_app/views/onboarding/onboarding_screen.dart';
import 'package:social_app/views/settings/setting_screen.dart';

GoRouter buildRouter({required AuthBloc authBloc,
  required bool hasSeenOnboarding
}) {
  const authFlowRoutes = {
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.registerPhone,
    AppRoutes.registerDetails,
    AppRoutes.forgotPassword,
    AppRoutes.phoneVerification,
    AppRoutes.emailVerification,
  };

  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggedIn = authBloc.state is AuthLoadedState;

      if (loc == AppRoutes.onboarding) {
        if (!hasSeenOnboarding) return null;
        return loggedIn ? AppRoutes.feeds : AppRoutes.login;
      }

      final isAuthFlow = authFlowRoutes.contains(loc);
      if (!loggedIn && !isAuthFlow) return AppRoutes.login;
      if (loggedIn && isAuthFlow) return AppRoutes.feeds;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.registerPhone,
        builder: (context, state) =>
            RegisterPhoneScreen(draft: state.extra as RegistrationDraft),
      ),
      GoRoute(
        path: AppRoutes.registerDetails,
        builder: (context, state) =>
            RegisterDetailsScreen(draft: state.extra as RegistrationDraft),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.phoneVerification,
        builder: (context, state) =>
            PhoneVerificationScreen(draft: state.extra as RegistrationDraft),
      ),
      GoRoute(
        path: AppRoutes.emailVerification,
        builder: (context, state) =>
            EmailVerificationScreen(draft: state.extra as RegistrationDraft),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.feeds,
                builder: (context, state) => const FeedsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.chats,
                builder: (context, state) => const ChatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.groups,
                builder: (context, state) => const GroupsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
