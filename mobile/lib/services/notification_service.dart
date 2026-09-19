import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:social_app/services/call_kit_service.dart';

// Runs in a separate background isolate when the app is backgrounded/killed
// — no access to getIt/CallBloc/any app state, only what's in `message`
// itself. A CALL push is data-only (see backend's sendCallPush: no
// top-level `notification` field) specifically so this branch runs instead
// of the OS auto-showing a generic banner that would fight CallKit's own
// native incoming-call UI.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  if (data['type'] != 'CALL') return;
  final callId = data['callId'] as String?;
  if (callId == null) return;
  await showIncomingCallKit(
    callId: callId,
    callerName: data['initiatorName'] as String? ?? 'Someone',
    isVideo: data['callType'] == 'VIDEO',
  );
}

class NotificationService {
  NotificationService(this._dio);

  final Dio _dio;
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'General Notifications',
    importance: Importance.high,
  );

  Future<void> init() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<void> registerToken() async {
    final token = await _messaging.getToken();
    if (token != null) await _sendTokenToBackend(token);
    _messaging.onTokenRefresh.listen(_sendTokenToBackend);
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      // Bare path: the Dio client's baseUrl already includes /api, so a
      // leading '/api/...' here previously resolved to .../api/api/...
      // and 404'd on every attempt.
      await _dio.post('/notifications/register-token', data: {'token': token});
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('Failed to register FCM token: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
