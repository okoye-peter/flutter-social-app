import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_app/core/networks/dio_client.dart';
import 'package:social_app/core/storage/token_storage.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/repositories/auth_repository.dart';
import 'package:social_app/services/notification_service.dart';

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

  getIt.registerSingleton<Dio>(
    DioClient.create(getIt<TokenStorage>(), getIt<UserCache>()),
  );

  getIt.registerSingleton<NotificationService>(
    NotificationService(getIt<Dio>()),
  );

  getIt.registerLazySingleton<AuthRepository>(() => AuthRepository());
}
