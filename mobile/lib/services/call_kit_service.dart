import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

// Deterministic (v5) native-call UUID derived from our backend's callId —
// NOT a stored mapping. The FCM background handler runs in a separate
// isolate with no shared state with the running app (see
// notification_service.dart's firebaseMessagingBackgroundHandler), so both
// it and CallBloc (once the app resumes) must be able to independently
// compute the exact same CallKit UUID for the same call.
String callKitUuidFor(String callId) => const Uuid().v5(Namespace.url.value, callId);

Future<void> showIncomingCallKit({
  required String callId,
  required String callerName,
  required bool isVideo,
}) {
  final params = CallKitParams(
    id: callKitUuidFor(callId),
    nameCaller: callerName,
    appName: 'Community Zone',
    type: isVideo ? 1 : 0,
    extra: {'callId': callId},
    android: const AndroidParams(
      isCustomNotification: true,
      isShowFullLockedScreen: true,
      incomingCallNotificationChannelName: 'Incoming Calls',
    ),
  );
  return FlutterCallkitIncoming.showCallkitIncoming(params);
}

Future<void> reportCallKitConnected(String callId) =>
    FlutterCallkitIncoming.setCallConnected(callKitUuidFor(callId));

Future<void> endCallKit(String callId) => FlutterCallkitIncoming.endCall(callKitUuidFor(callId));
