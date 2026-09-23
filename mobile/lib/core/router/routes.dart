import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/router/app_extra_codec.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/router/go_router_refresh_stream.dart';
import 'package:social_app/core/widgets/home_screen.dart';
import 'package:social_app/models/chat_details_args.dart';
import 'package:social_app/models/group_chat_args.dart';
import 'package:social_app/models/post_model.dart';
import 'package:social_app/models/registration_draft.dart';
import 'package:social_app/models/story_viewer_args.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/repositories/onboarding_repository.dart';
import 'package:social_app/viewmodels/auth/auth_bloc.dart';
import 'package:social_app/viewmodels/group_details/group_details_bloc.dart';
import 'package:social_app/views/auth/email_veritication_screen.dart';
import 'package:social_app/views/auth/forgot_password_screen.dart';
import 'package:social_app/views/auth/login_screen.dart';
import 'package:social_app/views/auth/phone_verification_screen.dart';
import 'package:social_app/views/auth/register_details_screen.dart';
import 'package:social_app/views/auth/register_phone_screen.dart';
import 'package:social_app/views/auth/register_screen.dart';
import 'package:social_app/views/auth/reset_password_screen.dart';
import 'package:social_app/views/calls/in_call_screen.dart';
import 'package:social_app/views/calls/incoming_call_screen.dart';
import 'package:social_app/views/calls/outgoing_call_screen.dart';
import 'package:social_app/views/chats/chat_list_screen.dart';
import 'package:social_app/views/chats/chat_screen.dart';
import 'package:social_app/views/chats/new_chat_list_screen.dart';
import 'package:social_app/views/feeds/create_feed.dart';
import 'package:social_app/views/feeds/create_story.dart';
import 'package:social_app/views/feeds/feeds_screen.dart';
import 'package:social_app/views/feeds/search_screen.dart';
import 'package:social_app/views/feeds/story_viewer_screen.dart';
import 'package:social_app/views/feeds/view_reels.dart';
import 'package:social_app/views/groups/create_group_screen.dart';
import 'package:social_app/views/groups/group_chat_screen.dart';
import 'package:social_app/views/groups/group_info_screen.dart';
import 'package:social_app/views/groups/groups_screen.dart';
import 'package:social_app/views/groups/member_picker_screen.dart';
import 'package:social_app/views/onboarding/onboarding_screen.dart';
import 'package:social_app/views/settings/setting_screen.dart';
import 'package:social_app/views/users/profile_screen.dart';

GoRouter buildRouter({
  required AuthBloc authBloc,
  required OnboardingStatusNotifier hasSeenOnboarding,
}) {
  const authFlowRoutes = {
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.registerPhone,
    AppRoutes.registerDetails,
    AppRoutes.forgotPassword,
    AppRoutes.resetPassword,
    AppRoutes.phoneVerification,
    AppRoutes.emailVerification,
  };

  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    extraCodec: const AppExtraCodec(),
    // Merged so either an auth-state change *or* completing onboarding
    // triggers a fresh redirect evaluation — a plain captured bool here
    // would leave this stuck with whatever value was true at app launch,
    // since nothing would ever prompt the router to re-check it.
    refreshListenable: Listenable.merge([
      GoRouterRefreshStream(authBloc.stream),
      hasSeenOnboarding,
    ]),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggedIn = authBloc.state is AuthLoadedState;

      if (loc == AppRoutes.onboarding) {
        if (!hasSeenOnboarding.value) return null;
        return loggedIn ? AppRoutes.feeds : AppRoutes.login;
      }

      // A fresh install must see onboarding first, however it was
      // opened — including via a deep link (e.g. a shared post) rather
      // than the launcher icon.
      if (!hasSeenOnboarding.value) return AppRoutes.onboarding;

      final isAuthFlow = authFlowRoutes.contains(loc);
      if (!loggedIn && !isAuthFlow) {
        // Preserve where the user was headed (e.g. a shared post's deep
        // link) so login can return them there instead of the default
        // feed — see LoginScreen's use of this same query param.
        return '${AppRoutes.login}?redirect=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (loggedIn && isAuthFlow) {
        final redirectTo = state.uri.queryParameters['redirect'];
        return redirectTo != null && redirectTo.isNotEmpty
            ? redirectTo
            : AppRoutes.feeds;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        // Public entry point for a shared post's App/Universal Link (see
        // the backend's /share/posts/:id preview page) — maps it to the
        // same in-app details route a normal in-app tap would use. A
        // logged-out visitor is caught by the auth gate above first (its
        // `redirect` query param brings them back here after login, and
        // this redirect resolves the same way on that second pass).
        path: '/share/posts/:id',
        redirect: (context, state) =>
            AppRoutes.feedDetailsPath(state.pathParameters['id']!),
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
        path: AppRoutes.resetPassword,
        builder: (context, state) =>
            ResetPasswordScreen(email: state.extra as String),
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
                    path: 'profile/:id',
                    builder: (context, state) => ProfileScreen(
                      userId: state.pathParameters['id']!,
                      initialUser: state.extra as UserModel?,
                    ),
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
                builder: (context, state) => const ChatListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const NewChatListScreen(),
                  ),
                  GoRoute(
                    path: 'messages',
                    builder: (context, state) {
                      final args = state.extra as ChatDetailsArgs;
                      return ChatScreen(
                        otherUser: args.otherUser,
                        conversationId: args.conversationId,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.groups,
                builder: (context, state) => const GroupsScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const CreateGroupScreen(),
                  ),
                  GoRoute(
                    path: 'chat',
                    builder: (context, state) =>
                        GroupChatScreen(args: state.extra as GroupChatArgs),
                  ),
                  GoRoute(
                    path: 'info',
                    // The chat screen's own bloc, so edits made here show
                    // up in its header without a refetch.
                    builder: (context, state) =>
                        GroupInfoScreen(bloc: state.extra as GroupDetailsBloc),
                  ),
                  GoRoute(
                    path: 'add-members',
                    builder: (context, state) => MemberPickerScreen(
                      args: state.extra as MemberPickerArgs? ?? const MemberPickerArgs(),
                    ),
                  ),
                ],
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
      // Top-level, not nested under any shell branch — a call must
      // overlay the whole app, reachable regardless of which shell tab is
      // active. State comes from the app-wide CallBloc singleton (see
      // main.dart), not from route `extra`.
      GoRoute(
        path: AppRoutes.callOutgoing,
        builder: (context, state) => const OutgoingCallScreen(),
      ),
      GoRoute(
        path: AppRoutes.callIncoming,
        builder: (context, state) => const IncomingCallScreen(),
      ),
      GoRoute(
        path: AppRoutes.callActive,
        builder: (context, state) => const InCallScreen(),
      ),
    ],
  );
}
