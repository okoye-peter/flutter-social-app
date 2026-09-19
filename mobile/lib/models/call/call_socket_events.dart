import 'package:social_app/core/enums/app_enums.dart';

/// call:started — broadcast to the conversation room when a call begins.
class CallStartedEvent {
  const CallStartedEvent({
    required this.callId,
    required this.conversationId,
    required this.type,
    required this.initiatorId,
  });

  final String callId;
  final String conversationId;
  final CallType type;
  final String initiatorId;

  factory CallStartedEvent.fromJson(Map<String, dynamic> json) => CallStartedEvent(
    callId: json['callId'] as String,
    conversationId: json['conversationId'] as String,
    type: CallType.fromJson(json['type'] as String?),
    initiatorId: json['initiatorId'] as String,
  );
}

/// call:incoming — sent to an invitee's own user room.
class CallIncomingEvent {
  const CallIncomingEvent({
    required this.callId,
    required this.conversationId,
    required this.type,
    required this.initiatorId,
  });

  final String callId;
  final String conversationId;
  final CallType type;
  final String initiatorId;

  factory CallIncomingEvent.fromJson(Map<String, dynamic> json) => CallIncomingEvent(
    callId: json['callId'] as String,
    conversationId: json['conversationId'] as String,
    type: CallType.fromJson(json['type'] as String?),
    initiatorId: json['initiatorId'] as String,
  );
}

/// Shared `{callId, userId}` shape for call:participant-joined,
/// call:declined, and call:participant-left. `existingParticipantIds` is
/// only present on call:participant-joined — the roster of who else was
/// already in the call before [userId] joined, so a newly-joining client
/// knows who to send WebRTC offers to.
class CallParticipantEvent {
  const CallParticipantEvent({
    required this.callId,
    required this.userId,
    this.existingParticipantIds = const [],
  });

  final String callId;
  final String userId;
  final List<String> existingParticipantIds;

  factory CallParticipantEvent.fromJson(Map<String, dynamic> json) => CallParticipantEvent(
    callId: json['callId'] as String,
    userId: json['userId'] as String,
    existingParticipantIds:
        (json['existingParticipantIds'] as List<dynamic>?)?.cast<String>() ?? const [],
  );
}

/// call:ended — reason is e.g. 'ended', 'no-answer'.
class CallEndedEvent {
  const CallEndedEvent({required this.callId, required this.reason});

  final String callId;
  final String reason;

  factory CallEndedEvent.fromJson(Map<String, dynamic> json) => CallEndedEvent(
    callId: json['callId'] as String,
    reason: json['reason'] as String? ?? 'ended',
  );
}

/// Shared `{callId, fromUserId, payload}` shape for call:offer,
/// call:answer, and call:ice-candidate — payload is the raw SDP/ICE JSON,
/// never interpreted server-side.
class CallSignalEvent {
  const CallSignalEvent({
    required this.callId,
    required this.fromUserId,
    required this.payload,
  });

  final String callId;
  final String fromUserId;
  final Map<String, dynamic> payload;

  factory CallSignalEvent.fromJson(Map<String, dynamic> json) => CallSignalEvent(
    callId: json['callId'] as String,
    fromUserId: json['fromUserId'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
  );
}

class CallErrorEvent {
  const CallErrorEvent({required this.message});

  final String message;

  factory CallErrorEvent.fromJson(Map<String, dynamic> json) => CallErrorEvent(
    message: json['message'] as String? ?? 'Call error',
  );
}
