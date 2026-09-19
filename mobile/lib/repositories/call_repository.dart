import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/models/call/call_socket_events.dart';
import 'package:social_app/services/socket_service.dart';

/// Socket-backed, not Dio-backed — call actions are socket-only per the
/// backend's design (realtime/handlers/call.ts), no REST equivalents exist.
class CallRepository {
  final SocketService _socket = getIt<SocketService>();

  void invite({required String conversationId, required CallType type}) {
    _socket.emit('call:invite', {
      'conversationId': conversationId,
      'type': type.toJson(),
    });
  }

  void accept(String callId) => _socket.emit('call:accept', {'callId': callId});

  void decline(String callId) => _socket.emit('call:decline', {'callId': callId});

  void leave(String callId) => _socket.emit('call:leave', {'callId': callId});

  void end(String callId) => _socket.emit('call:end', {'callId': callId});

  void sendOffer({
    required String callId,
    required String toUserId,
    required Map<String, dynamic> payload,
  }) {
    _socket.emit('call:offer', {
      'callId': callId,
      'toUserId': toUserId,
      'payload': payload,
    });
  }

  void sendAnswer({
    required String callId,
    required String toUserId,
    required Map<String, dynamic> payload,
  }) {
    _socket.emit('call:answer', {
      'callId': callId,
      'toUserId': toUserId,
      'payload': payload,
    });
  }

  void sendIceCandidate({
    required String callId,
    required String toUserId,
    required Map<String, dynamic> payload,
  }) {
    _socket.emit('call:ice-candidate', {
      'callId': callId,
      'toUserId': toUserId,
      'payload': payload,
    });
  }

  Stream<CallStartedEvent> get onCallStarted => _socket.events
      .where((e) => e.name == 'call:started')
      .map((e) => CallStartedEvent.fromJson(e.data));

  Stream<CallIncomingEvent> get onCallIncoming => _socket.events
      .where((e) => e.name == 'call:incoming')
      .map((e) => CallIncomingEvent.fromJson(e.data));

  Stream<CallParticipantEvent> get onParticipantJoined => _socket.events
      .where((e) => e.name == 'call:participant-joined')
      .map((e) => CallParticipantEvent.fromJson(e.data));

  Stream<CallParticipantEvent> get onDeclined => _socket.events
      .where((e) => e.name == 'call:declined')
      .map((e) => CallParticipantEvent.fromJson(e.data));

  Stream<CallParticipantEvent> get onParticipantLeft => _socket.events
      .where((e) => e.name == 'call:participant-left')
      .map((e) => CallParticipantEvent.fromJson(e.data));

  Stream<CallEndedEvent> get onEnded => _socket.events
      .where((e) => e.name == 'call:ended')
      .map((e) => CallEndedEvent.fromJson(e.data));

  Stream<CallSignalEvent> get onOffer => _socket.events
      .where((e) => e.name == 'call:offer')
      .map((e) => CallSignalEvent.fromJson(e.data));

  Stream<CallSignalEvent> get onAnswer => _socket.events
      .where((e) => e.name == 'call:answer')
      .map((e) => CallSignalEvent.fromJson(e.data));

  Stream<CallSignalEvent> get onIceCandidate => _socket.events
      .where((e) => e.name == 'call:ice-candidate')
      .map((e) => CallSignalEvent.fromJson(e.data));

  Stream<CallErrorEvent> get onError => _socket.events
      .where((e) => e.name == 'call:error')
      .map((e) => CallErrorEvent.fromJson(e.data));
}
