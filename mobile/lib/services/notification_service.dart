import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/models/chat_details_args.dart';
import 'package:social_app/models/group_chat_args.dart';
import 'package:social_app/repositories/group_repository.dart';
import 'package:social_app/repositories/user_repository.dart';
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
  final callId = data['callId'] as String?;
  if (callId == null) return;
  // Caller hung up (or it timed out) while this device was still ringing.
  if (data['type'] == 'CALL_CANCELLED') {
    await endCallKit(callId);
    return;
  }
  if (data['type'] != 'CALL') return;
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
      // Tap on a notification we displayed ourselves (app was foregrounded).
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        _onTap(Map<String, dynamic>.from(jsonDecode(payload) as Map));
      },
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    // Tap on an OS-displayed notification while the app was backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _onTap(m.data));
    // Tap that cold-started the app from a killed state. Deliberately not
    // awaited: on the iOS simulator (no APNs) this never completes, and
    // awaiting it here kept main() from reaching runApp — the app sat on the
    // native splash forever. Resolved later in [flushPendingTap].
    _initialMessage = _messaging
        .getInitialMessage()
        .timeout(const Duration(seconds: 10), onTimeout: () => null)
        .catchError((_) => null);
  }

  GoRouter? _router;
  Map<String, dynamic>? _pendingTap;
  Future<RemoteMessage?>? _initialMessage;

  // A cold-start tap arrives before the router exists and before login has
  // finished, so it is parked until [attachRouter] / [flushPendingTap].
  void attachRouter(GoRouter router) => _router = router;

  Future<void> flushPendingTap() async {
    final initialMessage = _initialMessage;
    if (initialMessage != null) {
      _initialMessage = null;
      final initial = await initialMessage;
      if (initial != null) _pendingTap ??= initial.data;
    }
    final data = _pendingTap;
    if (data == null) return;
    _pendingTap = null;
    _onTap(data);
  }

  Future<void> _onTap(Map<String, dynamic> data) async {
    final router = _router;
    if (router == null) {
      _pendingTap = data;
      return;
    }
    // Only messages are routed (MENTION is a group message that @-ed you);
    // CALL is owned by CallKit.
    final type = data['type'];
    if (type != 'MESSAGE' && type != 'MENTION') return;
    final actorId = data['actorId'] as String?;
    if (actorId == null) return;
    try {
      // A group message's push looks just like a direct one (same actorId =
      // sender), so check the conversation first — otherwise it would open
      // a 1:1 chat with the sender backed by the group's conversation id.
      final conversationId = data['conversationId'] as String?;
      if (conversationId != null) {
        final conversation = await GroupRepository().getGroup(conversationId);
        if (conversation.type == ConversationType.group) {
          router.push(
            AppRoutes.groupChat,
            extra: GroupChatArgs(
              conversationId: conversationId,
              name: conversation.name ?? '',
              image: conversation.image ?? '',
            ),
          );
          return;
        }
      }
      if (type != 'MESSAGE') return;
      final profile = await UserRepository().getUserProfile(actorId);
      router.push(
        AppRoutes.chatDetails,
        extra: ChatDetailsArgs(
          otherUser: profile.user,
          conversationId: data['conversationId'] as String?,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to open chat from notification: $e');
    }
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
      payload: jsonEncode(message.data),
    );
  }
}
