import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/router/go_router_refresh_stream.dart';
import 'package:social_app/core/widgets/home_screen.dart';
import 'package:social_app/models/post_model.dart';
import 'package:social_app/models/registration_draft.dart';
import 'package:social_app/models/story_viewer_args.dart';
import 'package:social_app/viewmodels/auth/auth_bloc.dart';
import 'package:social_app/views/auth/email_veritication_screen.dart';
import 'package:social_app/views/auth/forgot_password_screen.dart';
import 'package:social_app/views/auth/login_screen.dart';
import 'package:social_app/views/auth/phone_verification_screen.dart';
import 'package:social_app/views/auth/register_details_screen.dart';
import 'package:social_app/views/auth/register_phone_screen.dart';
import 'package:social_app/views/auth/register_screen.dart';
import 'package:social_app/views/chats/chats_screen.dart';
import 'package:social_app/views/feeds/create_feed.dart';
import 'package:social_app/views/feeds/create_story.dart';
import 'package:social_app/views/feeds/feeds_screen.dart';
import 'package:social_app/views/feeds/search_screen.dart';
import 'package:social_app/views/feeds/story_viewer_screen.dart';
import 'package:social_app/views/feeds/view_reels.dart';
import 'package:social_app/views/groups/groups_screen.dart';
import 'package:social_app/views/onboarding/onboarding_screen.dart';
import 'package:social_app/views/settings/setting_screen.dart';

GoRouter buildRouter({
  required AuthBloc authBloc,
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
        builder: (context, state, navigationShell) => HomeScaffold(
          navigationShell: navigationShell,
          currentFullPath: state.fullPath,
        ),    
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.feeds,
                builder: (context, state) => const FeedsScreen(),
                routes: [
                  // Must come before ':id' below — otherwise go_router
                  // matches 'search' as the :id param, same as Express
                  // would (see the routes.ts comment on the backend).
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => const SearchScreen(),
                  ),
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const CreateFeedScreen(),
                  ),
                  GoRoute(
                    path: 'create-story',
                    builder: (context, state) => const CreateStoryScreen(),
                  ),
                  GoRoute(
                    path: 'story-viewer',
                    pageBuilder: (context, state) {
                      final args = state.extra as StoryViewerArgs;
                      return CustomTransitionPage<void>(
                        key: state.pageKey,
                        child: StoryViewerScreen(
                          groups: args.groups,
                          initialGroupIndex: args.initialGroupIndex,
                          onStoryViewed: args.onStoryViewed,
                        ),
                        transitionDuration: const Duration(milliseconds: 220),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 180,
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              final curved = CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                                reverseCurve: Curves.easeInCubic,
                              );
                              return FadeTransition(
                                opacity: curved,
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.92,
                                    end: 1.0,
                                  ).animate(curved),
                                  child: child,
                                ),
                              );
                            },
                      );
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ViewReelDetailsScreen(
                      reelId: state.pathParameters['id']!,
                      // Set when pushed in-app from a feed that already has
                      // the post loaded (skips the network round trip);
                      // null when arriving via a deep link, so the screen
                      // falls back to fetching by reelId.
                      initialPost: state.extra as PostModel?,
                    ),
                  ),
                ],
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
