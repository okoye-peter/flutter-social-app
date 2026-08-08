import 'package:go_router/go_router.dart';
import 'package:social_app/views/auth/login_screen.dart';
import 'package:social_app/views/home/onboarding_screen.dart';

GoRouter buildRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );
}