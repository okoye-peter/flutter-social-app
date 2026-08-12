import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:social_app/core/networks/dio_client.dart';
import 'package:social_app/services/notification_service.dart';

final getIt = GetIt.instance;

void setupLocator() {
  getIt.registerSingleton<Dio>(DioClient.create());

  getIt.registerSingleton<NotificationService>(
    NotificationService(getIt<Dio>()),
  );
}