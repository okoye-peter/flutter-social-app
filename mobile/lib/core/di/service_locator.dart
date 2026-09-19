import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_app/core/auth/auth_session_notifier.dart';
import 'package:social_app/core/networks/dio_client.dart';
import 'package:social_app/core/storage/token_storage.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/repositories/auth_repository.dart';
import 'package:social_app/repositories/onboarding_repository.dart';
import 'package:social_app/services/notification_service.dart';
import 'package:social_app/services/socket_service.dart';
import 'package:social_app/viewmodels/call/call_bloc.dart';

final getIt = GetIt.instance;

Future<void> setupLocator() async {
  getIt.registerSingleton<FlutterSecureStorage>(const FlutterSecureStorage());

  final tokenStorage = TokenStorage(getIt<FlutterSecureStorage>());
  await tokenStorage.load();
  getIt.registerSingleton<TokenStorage>(tokenStorage);

  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);

  final userCache = UserCache(getIt<SharedPreferences>());
  userCache.load();
  getIt.registerSingleton<UserCache>(userCache);

  getIt.registerSingleton<AuthSessionNotifier>(AuthSessionNotifier());

  final hasSeenOnboarding = await OnboardingRepository().hasSeenOnboarding();
  getIt.registerSingleton<OnboardingStatusNotifier>(
    OnboardingStatusNotifier(hasSeenOnboarding),
  );

  getIt.registerSingleton<Dio>(
    DioClient.create(
      getIt<TokenStorage>(),
      getIt<UserCache>(),
      getIt<AuthSessionNotifier>(),
    ),
  );

  getIt.registerSingleton<NotificationService>(
    NotificationService(getIt<Dio>()),
  );

  getIt.registerSingleton<SocketService>(SocketService(getIt<TokenStorage>()));

  // App-wide singleton, not screen-scoped — an incoming call must be
  // receivable from any screen. Constructed once here, provided at the
  // app root (see main.dart), never disposed until app teardown.
  getIt.registerSingleton<CallBloc>(CallBloc());

  getIt.registerLazySingleton<AuthRepository>(() => AuthRepository());
}
