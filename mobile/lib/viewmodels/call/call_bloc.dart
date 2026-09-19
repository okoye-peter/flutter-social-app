import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart' as callkit;
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/call/call_socket_events.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/repositories/call_repository.dart';
import 'package:social_app/repositories/user_repository.dart';
import 'package:social_app/services/call_kit_service.dart';
import 'package:social_app/services/webrtc/webrtc_engine.dart';

part 'call_event.dart';
part 'call_state.dart';

// App-wide singleton (registered in service_locator.dart, provided at the
// app root) — the one deliberate exception to this codebase's usual
// screen-scoped bloc pattern (see DirectMessageBloc), since an incoming
// call must be receivable from any screen, not just one that happens to
// construct this bloc.
class CallBloc extends Bloc<CallEvent, CallState> {
  CallBloc() : super(const CallState()) {
    on<StartOutgoingCallEvent>(_processStartOutgoingCall, transformer: sequential());
    on<AcceptCallEvent>(_processAccept, transformer: sequential());
    on<DeclineCallEvent>(_processDecline, transformer: sequential());
    on<LeaveCallEvent>(_processLeave, transformer: sequential());
    on<ToggleMuteEvent>(_processToggleMute, transformer: sequential());
    on<ToggleCameraEvent>(_processToggleCamera, transformer: sequential());
    on<ToggleSpeakerEvent>(_processToggleSpeaker, transformer: sequential());
    on<IncomingCallReceivedEvent>(_processIncomingCall, transformer: sequential());
    on<_CallStartedConfirmedEvent>(_processCallStarted, transformer: sequential());
    on<ParticipantJoinedEvent>(_processParticipantJoined, transformer: sequential());
    on<ParticipantGoneEvent>(_processParticipantGone, transformer: sequential());
    on<CallEndedRemotelyEvent>(_processCallEndedRemotely, transformer: sequential());
    on<CallTickEvent>(_processTick, transformer: sequential());
    on<_CallErrorEvent>(_processCallError, transformer: sequential());
    on<_ConnectTimeoutEvent>(_processConnectTimeout, transformer: sequential());
    // concurrent(), not sequential(): ICE candidates for different peers
    // (group calls) progress independently and shouldn't block each other,
    // matching how DirectMessageBloc already uses concurrent() for
    // independent async work.
    on<RemoteOfferReceivedEvent>(_processRemoteOffer, transformer: concurrent());
    on<RemoteAnswerReceivedEvent>(_processRemoteAnswer, transformer: concurrent());
    on<RemoteIceCandidateReceivedEvent>(_processRemoteIceCandidate, transformer: concurrent());
    on<_PeerConnectionStateChangedEvent>(_processPeerConnectionStateChanged, transformer: concurrent());

    // Native CallKit/ConnectionService actions (answer/decline/end from the
    // lock screen) feed into the exact same events the in-app UI uses —
    // CallBloc stays the single source of truth, CallKit only reports into
    // it. Known gap (needs real-device verification): if the app was fully
    // killed and CallKit launched it fresh via an Accept tap, this listener
    // may attach after that first event already fired — a startup check
    // against FlutterCallkitIncoming.activeCalls() would close that gap,
    // deferred pending device testing.
    _callKitSubscription = FlutterCallkitIncoming.onEvent.listen(_handleCallKitEvent);

    _subscriptions = [
      _repo.onCallStarted.listen((e) => add(_CallStartedConfirmedEvent(e))),
      _repo.onCallIncoming.listen((e) => add(IncomingCallReceivedEvent(e))),
      _repo.onOffer.listen((e) => add(RemoteOfferReceivedEvent(e))),
      _repo.onAnswer.listen((e) => add(RemoteAnswerReceivedEvent(e))),
      _repo.onIceCandidate.listen((e) => add(RemoteIceCandidateReceivedEvent(e))),
      _repo.onParticipantJoined.listen((e) => add(ParticipantJoinedEvent(e))),
      _repo.onDeclined.listen((e) => add(ParticipantGoneEvent(e.userId, declined: true))),
      _repo.onError.listen((e) => add(_CallErrorEvent(e.message))),
      _repo.onParticipantLeft.listen((e) => add(ParticipantGoneEvent(e.userId))),
      _repo.onEnded.listen((e) => add(CallEndedRemotelyEvent(e.reason))),
    ];

    _peers.onLocalIceCandidate = (remoteUserId, candidate) {
      final callId = state.callId;
      if (callId == null) return;
      _repo.sendIceCandidate(
        callId: callId,
        toUserId: remoteUserId,
        payload: iceCandidateToJson(candidate),
      );
    };
    _peers.onConnectionState = (userId, connState) =>
        add(_PeerConnectionStateChangedEvent(userId, connState));
  }

  final CallRepository _repo = CallRepository();
  final UserRepository _userRepo = UserRepository();
  final LocalMediaController _localMedia = LocalMediaController();
  final PeerConnectionManager _peers = PeerConnectionManager();
  late final List<StreamSubscription<Object?>> _subscriptions;
  late final StreamSubscription<callkit.CallEvent?> _callKitSubscription;
  Timer? _tickTimer;
  Timer? _connectTimer;

  // How long a call may sit in `connecting` (accepted, but no peer
  // connection established) before giving up — otherwise a media/ICE
  // failure leaves both users on a spinner until someone hangs up.
  static const _connectTimeout = Duration(seconds: 30);

  void _startConnectTimer() {
    _connectTimer?.cancel();
    _connectTimer = Timer(_connectTimeout, () => add(const _ConnectTimeoutEvent()));
  }

  // Shows the reason (main.dart toasts on `ended`), then returns to idle so
  // a failed attempt never wedges the bloc — a state stuck on `ended` made
  // every later StartOutgoingCallEvent bail out at the isIdle check.
  Future<void> _failCall(Emitter<CallState> emit, String message) async {
    emit(state.copyWith(status: CallStatus.ended, errorMessage: message));
    await _resetToIdle(emit);
  }

  Future<void> _processCallError(_CallErrorEvent event, Emitter<CallState> emit) async {
    // A call:error while idle isn't about a call this device is in.
    if (state.isIdle) return;
    await _failCall(emit, event.message);
  }

  Future<void> _processConnectTimeout(_ConnectTimeoutEvent event, Emitter<CallState> emit) async {
    if (state.status != CallStatus.connecting) return;
    final callId = state.callId;
    if (callId != null) _repo.leave(callId);
    await _failCall(emit, "Couldn't connect the call. Check your network and try again.");
  }

  void _handleCallKitEvent(callkit.CallEvent? event) {
    if (event == null) return;
    final body = event.body;
    String? callId;
    if (body is Map) {
      final extra = body['extra'];
      if (extra is Map) callId = extra['callId'] as String?;
    }
    if (callId == null || callId != state.callId) return;

    switch (event.event) {
      case callkit.Event.actionCallAccept:
        add(const AcceptCallEvent());
      case callkit.Event.actionCallDecline:
      case callkit.Event.actionCallTimeout:
        add(const DeclineCallEvent());
      case callkit.Event.actionCallEnded:
        add(const LeaveCallEvent());
      default:
        break;
    }
  }

  String? get _myUserId => getIt<UserCache>().current?.id;

  // Read by the in-call screen to render local/remote video — these are
  // live objects mutated in place by LocalMediaController/
  // PeerConnectionManager, not part of CallState/Equatable, since a
  // MediaStream/RTCVideoRenderer isn't meaningfully comparable value state.
  MediaStream? get localStream => _localMedia.localStream;
  Map<String, RTCVideoRenderer> get remoteRenderers => _peers.remoteRenderers;

  Future<void> _processStartOutgoingCall(
    StartOutgoingCallEvent event,
    Emitter<CallState> emit,
  ) async {
    if (!state.isIdle) return;
    emit(
      CallState(
        status: CallStatus.outgoingRinging,
        conversationId: event.conversationId,
        type: event.type,
        otherUser: event.otherUser,
      ),
    );
    try {
      await _localMedia.acquire(video: event.type == CallType.video);
    } catch (_) {
      await _failCall(emit, 'Could not access microphone/camera');
      return;
    }
    _repo.invite(conversationId: event.conversationId, type: event.type);
  }

  Future<void> _processCallStarted(
    _CallStartedConfirmedEvent wrapper,
    Emitter<CallState> emit,
  ) async {
    final event = wrapper.event;
    // Ignore call:started broadcasts for someone else's call in a shared
    // conversation room, or ones that arrive after we already have a callId.
    if (state.status != CallStatus.outgoingRinging || state.callId != null) return;
    if (event.initiatorId != _myUserId) return;
    emit(state.copyWith(callId: event.callId));
  }

  Future<void> _processIncomingCall(
    IncomingCallReceivedEvent wrapper,
    Emitter<CallState> emit,
  ) async {
    final event = wrapper.event;
    if (!state.isIdle) {
      _repo.decline(event.callId); // already on another call — busy
      return;
    }
    emit(
      CallState(
        status: CallStatus.incomingRinging,
        callId: event.callId,
        conversationId: event.conversationId,
        type: event.type,
      ),
    );
    try {
      final profile = await _userRepo.getUserProfile(event.initiatorId);
      if (state.callId == event.callId && state.status == CallStatus.incomingRinging) {
        emit(state.copyWith(otherUser: profile.user));
      }
    } catch (_) {
      // Non-fatal — the call still works without the caller's name/avatar.
    }
  }

  Future<void> _processAccept(AcceptCallEvent event, Emitter<CallState> emit) async {
    final callId = state.callId;
    if (callId == null || state.status != CallStatus.incomingRinging) return;
    emit(state.copyWith(status: CallStatus.connecting));
    try {
      await _localMedia.acquire(video: state.type == CallType.video);
    } catch (_) {
      _repo.decline(callId);
      await _failCall(emit, 'Could not access microphone/camera');
      return;
    }
    _repo.accept(callId);
    _startConnectTimer();
  }

  Future<void> _processDecline(DeclineCallEvent event, Emitter<CallState> emit) async {
    final callId = state.callId;
    if (callId != null) _repo.decline(callId);
    await _resetToIdle(emit);
  }

  Future<void> _processLeave(LeaveCallEvent event, Emitter<CallState> emit) async {
    final callId = state.callId;
    // leave, never end: `end` requires being the call initiator
    // server-side — leave is the universal "hang up" for any participant,
    // and the backend already auto-ends the call once nobody's left joined.
    if (callId != null) _repo.leave(callId);
    await _resetToIdle(emit);
  }

  Future<void> _processCallEndedRemotely(
    CallEndedRemotelyEvent event,
    Emitter<CallState> emit,
  ) async {
    await _resetToIdle(emit);
  }

  Future<void> _processParticipantJoined(
    ParticipantJoinedEvent wrapper,
    Emitter<CallState> emit,
  ) async {
    final event = wrapper.event;
    if (state.callId != event.callId) return;

    if (event.userId == _myUserId) {
      // I'm the one who just joined — per the deterministic mesh rule, I
      // offer to everyone already in the call (empty list for a plain 1:1
      // call where I'm the callee accepting the initiator's invite).
      emit(state.copyWith(status: CallStatus.connecting));
      _startConnectTimer();
      final stream = _localMedia.localStream;
      if (stream == null) return;
      for (final existingId in event.existingParticipantIds) {
        final offer = await _peers.createOffer(existingId, stream);
        _repo.sendOffer(
          callId: event.callId,
          toUserId: existingId,
          payload: sessionDescriptionToJson(offer),
        );
      }
    } else {
      // Someone else joined after us — they will send US the offer per the
      // same rule; just track them as present.
      final participants = {...state.participants};
      participants[event.userId] = ParticipantMediaState(userId: event.userId, joined: true);
      if (state.status == CallStatus.outgoingRinging) _startConnectTimer();
      emit(
        state.copyWith(
          participants: participants,
          status: state.status == CallStatus.outgoingRinging ? CallStatus.connecting : state.status,
        ),
      );
    }
  }

  Future<void> _processParticipantGone(
    ParticipantGoneEvent event,
    Emitter<CallState> emit,
  ) async {
    await _peers.closePeer(event.userId);
    final participants = {...state.participants}..remove(event.userId);
    if (participants.isEmpty && !state.isIdle) {
      // Without this the server never learns we're gone, the call stays
      // ONGOING with one participant, and every later invite in this
      // conversation is rejected as "already has an active call".
      final callId = state.callId;
      if (!event.declined && callId != null) _repo.leave(callId);
      await _resetToIdle(emit);
    } else {
      emit(state.copyWith(participants: participants));
    }
  }

  Future<void> _processRemoteOffer(
    RemoteOfferReceivedEvent wrapper,
    Emitter<CallState> emit,
  ) async {
    final event = wrapper.event;
    if (state.callId != event.callId) return;
    final stream = _localMedia.localStream;
    if (stream == null) return;

    final offer = sessionDescriptionFromJson(event.payload);
    final answer = await _peers.createAnswer(event.fromUserId, offer, stream);
    _repo.sendAnswer(
      callId: event.callId,
      toUserId: event.fromUserId,
      payload: sessionDescriptionToJson(answer),
    );

    final participants = {...state.participants};
    participants[event.fromUserId] =
        (participants[event.fromUserId] ?? ParticipantMediaState(userId: event.fromUserId))
            .copyWith(joined: true);
    emit(state.copyWith(participants: participants));
  }

  Future<void> _processRemoteAnswer(
    RemoteAnswerReceivedEvent wrapper,
    Emitter<CallState> emit,
  ) async {
    final event = wrapper.event;
    if (state.callId != event.callId) return;
    await _peers.setRemoteAnswer(event.fromUserId, sessionDescriptionFromJson(event.payload));
  }

  Future<void> _processRemoteIceCandidate(
    RemoteIceCandidateReceivedEvent wrapper,
    Emitter<CallState> emit,
  ) async {
    final event = wrapper.event;
    if (state.callId != event.callId) return;
    await _peers.addIceCandidate(event.fromUserId, iceCandidateFromJson(event.payload));
  }

  Future<void> _processPeerConnectionStateChanged(
    _PeerConnectionStateChangedEvent event,
    Emitter<CallState> emit,
  ) async {
    final participants = {...state.participants};
    final existing = participants[event.userId] ?? ParticipantMediaState(userId: event.userId);
    participants[event.userId] = existing.copyWith(connectionState: event.connectionState);

    final anyConnected = participants.values.any(
      (p) => p.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected,
    );
    final becameActive = anyConnected && state.status == CallStatus.connecting;
    emit(
      state.copyWith(
        participants: participants,
        status: becameActive ? CallStatus.active : state.status,
      ),
    );
    if (becameActive) {
      _connectTimer?.cancel();
      _startTicking();
      final callId = state.callId;
      if (callId != null) unawaited(reportCallKitConnected(callId).catchError((_) {}));
    }
  }

  Future<void> _processToggleMute(ToggleMuteEvent event, Emitter<CallState> emit) async {
    final muted = !state.localMuted;
    _localMedia.setMuted(muted);
    emit(state.copyWith(localMuted: muted));
  }

  Future<void> _processToggleCamera(ToggleCameraEvent event, Emitter<CallState> emit) async {
    final enabled = !state.localVideoEnabled;
    _localMedia.setVideoEnabled(enabled);
    emit(state.copyWith(localVideoEnabled: enabled));
  }

  Future<void> _processToggleSpeaker(ToggleSpeakerEvent event, Emitter<CallState> emit) async {
    final on = !state.speakerOn;
    await Helper.setSpeakerphoneOn(on);
    emit(state.copyWith(speakerOn: on));
  }

  Future<void> _processTick(CallTickEvent event, Emitter<CallState> emit) async {
    if (state.status != CallStatus.active) return;
    emit(state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1)));
  }

  void _startTicking() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => add(const CallTickEvent()));
  }

  Future<void> _resetToIdle(Emitter<CallState> emit) async {
    final callId = state.callId;
    _tickTimer?.cancel();
    _tickTimer = null;
    _connectTimer?.cancel();
    _connectTimer = null;
    await _peers.closeAll();
    await _localMedia.dispose();
    if (callId != null) unawaited(endCallKit(callId).catchError((_) {}));
    emit(const CallState());
  }

  @override
  Future<void> close() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _callKitSubscription.cancel();
    _tickTimer?.cancel();
    _connectTimer?.cancel();
    await _peers.closeAll();
    await _localMedia.dispose();
    return super.close();
  }
}
