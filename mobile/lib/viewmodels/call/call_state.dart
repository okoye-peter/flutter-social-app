part of 'call_bloc.dart';

enum CallStatus { idle, outgoingRinging, incomingRinging, connecting, active, ended }

class ParticipantMediaState extends Equatable {
  const ParticipantMediaState({
    required this.userId,
    this.joined = false,
    this.connectionState,
  });

  final String userId;
  final bool joined;
  final RTCPeerConnectionState? connectionState;

  ParticipantMediaState copyWith({
    bool? joined,
    RTCPeerConnectionState? connectionState,
  }) {
    return ParticipantMediaState(
      userId: userId,
      joined: joined ?? this.joined,
      connectionState: connectionState ?? this.connectionState,
    );
  }

  @override
  List<Object?> get props => [userId, joined, connectionState];
}

// A single evolvable state (status + fields) rather than a sealed
// per-phase hierarchy: call state carries a lot of orthogonal info (media
// flags, elapsed timer, participants) that needs to persist and update
// across transitions — a sealed hierarchy would force re-specifying all of
// it at every transition, the same problem LoadedChatSearchState's
// copyWith solved for chat search earlier.
class CallState extends Equatable {
  const CallState({
    this.status = CallStatus.idle,
    this.callId,
    this.conversationId,
    this.type = CallType.voice,
    this.otherUser,
    this.participants = const {},
    this.localMuted = false,
    this.localVideoEnabled = true,
    this.speakerOn = false,
    this.elapsed = Duration.zero,
    this.errorMessage,
  });

  final CallStatus status;
  final String? callId;
  final String? conversationId;
  final CallType type;

  // The other party (1:1) or the caller (incoming) — group calls (phase 4)
  // read participant identity from `participants` instead.
  final UserModel? otherUser;
  final Map<String, ParticipantMediaState> participants;
  final bool localMuted;
  final bool localVideoEnabled;
  final bool speakerOn;
  final Duration elapsed;
  final String? errorMessage;

  bool get isActive => status == CallStatus.active;
  bool get isIdle => status == CallStatus.idle;

  static const _unset = Object();

  CallState copyWith({
    CallStatus? status,
    Object? callId = _unset,
    Object? conversationId = _unset,
    CallType? type,
    Object? otherUser = _unset,
    Map<String, ParticipantMediaState>? participants,
    bool? localMuted,
    bool? localVideoEnabled,
    bool? speakerOn,
    Duration? elapsed,
    Object? errorMessage = _unset,
  }) {
    return CallState(
      status: status ?? this.status,
      callId: identical(callId, _unset) ? this.callId : callId as String?,
      conversationId: identical(conversationId, _unset)
          ? this.conversationId
          : conversationId as String?,
      type: type ?? this.type,
      otherUser: identical(otherUser, _unset) ? this.otherUser : otherUser as UserModel?,
      participants: participants ?? this.participants,
      localMuted: localMuted ?? this.localMuted,
      localVideoEnabled: localVideoEnabled ?? this.localVideoEnabled,
      speakerOn: speakerOn ?? this.speakerOn,
      elapsed: elapsed ?? this.elapsed,
      errorMessage: identical(errorMessage, _unset) ? this.errorMessage : errorMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
    status,
    callId,
    conversationId,
    type,
    otherUser,
    participants,
    localMuted,
    localVideoEnabled,
    speakerOn,
    elapsed,
    errorMessage,
  ];
}
