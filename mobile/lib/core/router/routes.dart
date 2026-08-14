import 'package:go_router/go_router.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/widgets/home_screen.dart';
import 'package:social_app/views/auth/email_veritication_screen.dart';
import 'package:social_app/views/auth/forgot_password_screen.dart';
import 'package:social_app/views/auth/login_screen.dart';
import 'package:social_app/views/auth/phone_verification_screen.dart';
import 'package:social_app/views/auth/register_screen.dart';
import 'package:social_app/views/chats/chats_screen.dart';
import 'package:social_app/views/feeds/feed_screen.dart';
import 'package:social_app/views/groups/groups_screen.dart';
import 'package:social_app/views/onboarding/onboarding_screen.dart';
import 'package:social_app/views/settings/setting_screen.dart';

GoRouter buildRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
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
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.phoneVerification,
        builder: (context, state) =>
            PhoneVerificationScreen(phoneNumber: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: AppRoutes.emailVerification,
        builder: (context, state) =>
            EmailVerificationScreen(email: state.extra as String? ?? ''),
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
