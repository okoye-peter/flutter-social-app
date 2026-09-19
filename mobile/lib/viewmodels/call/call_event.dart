part of 'call_bloc.dart';

sealed class CallEvent extends Equatable {
  const CallEvent();

  @override
  List<Object?> get props => [];
}

final class StartOutgoingCallEvent extends CallEvent {
  const StartOutgoingCallEvent({
    required this.conversationId,
    required this.otherUser,
    required this.type,
  });

  final String conversationId;
  final UserModel otherUser;
  final CallType type;

  @override
  List<Object?> get props => [conversationId, otherUser, type];
}

final class AcceptCallEvent extends CallEvent {
  const AcceptCallEvent();
}

final class DeclineCallEvent extends CallEvent {
  const DeclineCallEvent();
}

final class LeaveCallEvent extends CallEvent {
  const LeaveCallEvent();
}

final class ToggleMuteEvent extends CallEvent {
  const ToggleMuteEvent();
}

final class ToggleCameraEvent extends CallEvent {
  const ToggleCameraEvent();
}

final class ToggleSpeakerEvent extends CallEvent {
  const ToggleSpeakerEvent();
}

// Internal — fed by CallRepository's streams, never dispatched by UI
// directly. Kept as events (not handled straight in the stream listener)
// so every state mutation is serialized through the bloc's event queue.
final class IncomingCallReceivedEvent extends CallEvent {
  const IncomingCallReceivedEvent(this.event);
  final CallIncomingEvent event;
}

final class _CallStartedConfirmedEvent extends CallEvent {
  const _CallStartedConfirmedEvent(this.event);
  final CallStartedEvent event;
}

final class _PeerConnectionStateChangedEvent extends CallEvent {
  const _PeerConnectionStateChangedEvent(this.userId, this.connectionState);
  final String userId;
  final RTCPeerConnectionState connectionState;
}

final class RemoteOfferReceivedEvent extends CallEvent {
  const RemoteOfferReceivedEvent(this.event);
  final CallSignalEvent event;
}

final class RemoteAnswerReceivedEvent extends CallEvent {
  const RemoteAnswerReceivedEvent(this.event);
  final CallSignalEvent event;
}

final class RemoteIceCandidateReceivedEvent extends CallEvent {
  const RemoteIceCandidateReceivedEvent(this.event);
  final CallSignalEvent event;
}

final class ParticipantJoinedEvent extends CallEvent {
  const ParticipantJoinedEvent(this.event);
  final CallParticipantEvent event;
}

final class ParticipantGoneEvent extends CallEvent {
  const ParticipantGoneEvent(this.userId, {this.declined = false});
  final String userId;

  /// True for call:declined (the server already resolved the call), false
  /// for call:participant-left (the call may still be open server-side).
  final bool declined;
}

final class _CallErrorEvent extends CallEvent {
  const _CallErrorEvent(this.message);
  final String message;
}

final class _ConnectTimeoutEvent extends CallEvent {
  const _ConnectTimeoutEvent();
}

final class CallEndedRemotelyEvent extends CallEvent {
  const CallEndedRemotelyEvent(this.reason);
  final String reason;
}

final class CallTickEvent extends CallEvent {
  const CallTickEvent();
}
