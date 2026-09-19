import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

Map<String, dynamic> sessionDescriptionToJson(RTCSessionDescription desc) => {
  'sdp': desc.sdp,
  'type': desc.type,
};

RTCSessionDescription sessionDescriptionFromJson(Map<String, dynamic> json) =>
    RTCSessionDescription(json['sdp'] as String?, json['type'] as String?);

Map<String, dynamic> iceCandidateToJson(RTCIceCandidate candidate) => {
  'candidate': candidate.candidate,
  'sdpMid': candidate.sdpMid,
  'sdpMLineIndex': candidate.sdpMLineIndex,
};

RTCIceCandidate iceCandidateFromJson(Map<String, dynamic> json) => RTCIceCandidate(
  json['candidate'] as String?,
  json['sdpMid'] as String?,
  json['sdpMLineIndex'] as int?,
);

/// Local mic/camera acquisition and control — separate from peer-connection
/// bookkeeping (PeerConnectionManager below) since one local stream feeds
/// every peer connection in a group call.
class LocalMediaController {
  MediaStream? _localStream;
  MediaStream? get localStream => _localStream;

  Future<MediaStream> acquire({required bool video}) async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video': video ? {'facingMode': 'user'} : false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    return _localStream!;
  }

  void setMuted(bool muted) {
    for (final track in _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
  }

  void setVideoEnabled(bool enabled) {
    for (final track in _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
  }

  Future<void> dispose() async {
    await _localStream?.dispose();
    _localStream = null;
  }
}

/// One RTCPeerConnection per remote participant, keyed by userId — a plain
/// 1:1 call just has one entry. Designed for group mesh from the start so
/// Phase 4 (group calls) extends this rather than rewriting it.
///
/// Offer/answer role to avoid glare in a mesh: a newly-joining participant
/// always sends the first offer to everyone already in the call — callers
/// of this class (CallBloc) are responsible for following that rule, this
/// class just executes whichever role it's told to (createOffer vs
/// createAnswer).
class PeerConnectionManager {
  final Map<String, RTCPeerConnection> _connections = {};
  final Map<String, RTCVideoRenderer> remoteRenderers = {};
  final Map<String, List<RTCIceCandidate>> _pendingCandidates = {};
  final Map<String, bool> _remoteDescriptionSet = {};

  // STUN alone can't connect two peers behind different NATs (e.g. a phone
  // on Wi-Fi and an emulator's private 10.0.2.x network) — that needs a
  // TURN relay. Set TURN_URL (+ TURN_USERNAME / TURN_CREDENTIAL) in .env to
  // enable one; unset, only public STUN is used.
  static Map<String, dynamic> get _configuration {
    final turnUrl = dotenv.maybeGet('TURN_URL');
    return {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        if (turnUrl != null && turnUrl.isNotEmpty)
          {
            'urls': turnUrl,
            'username': dotenv.maybeGet('TURN_USERNAME') ?? '',
            'credential': dotenv.maybeGet('TURN_CREDENTIAL') ?? '',
          },
      ],
    };
  }

  /// Called whenever a local candidate is gathered for [remoteUserId] —
  /// wire this to CallRepository.sendIceCandidate.
  void Function(String remoteUserId, RTCIceCandidate candidate)? onLocalIceCandidate;

  /// Called whenever [remoteUserId]'s connection state changes.
  void Function(String remoteUserId, RTCPeerConnectionState state)? onConnectionState;

  Future<RTCPeerConnection> _getOrCreate(String remoteUserId, MediaStream localStream) async {
    final existing = _connections[remoteUserId];
    if (existing != null) return existing;

    final pc = await createPeerConnection(_configuration);
    for (final track in localStream.getTracks()) {
      await pc.addTrack(track, localStream);
    }
    pc.onIceCandidate = (candidate) {
      final text = candidate.candidate;
      if (text == null) return;
      if (kDebugMode) debugPrint('[webrtc] local candidate: $text');
      onLocalIceCandidate?.call(remoteUserId, candidate);
    };
    pc.onIceConnectionState = (state) {
      if (kDebugMode) debugPrint('[webrtc] ice state ($remoteUserId): $state');
    };
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) _attachRemoteStream(remoteUserId, event.streams.first);
    };
    pc.onConnectionState = (state) {
      if (kDebugMode) debugPrint('[webrtc] connection state ($remoteUserId): $state');
      onConnectionState?.call(remoteUserId, state);
    };

    _connections[remoteUserId] = pc;
    _remoteDescriptionSet[remoteUserId] = false;
    return pc;
  }

  Future<void> _attachRemoteStream(String remoteUserId, MediaStream stream) async {
    var renderer = remoteRenderers[remoteUserId];
    if (renderer == null) {
      renderer = RTCVideoRenderer();
      await renderer.initialize();
      remoteRenderers[remoteUserId] = renderer;
    }
    renderer.srcObject = stream;
  }

  Future<RTCSessionDescription> createOffer(String remoteUserId, MediaStream localStream) async {
    final pc = await _getOrCreate(remoteUserId, localStream);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer(
    String remoteUserId,
    RTCSessionDescription remoteOffer,
    MediaStream localStream,
  ) async {
    final pc = await _getOrCreate(remoteUserId, localStream);
    await pc.setRemoteDescription(remoteOffer);
    _remoteDescriptionSet[remoteUserId] = true;
    await _flushPendingCandidates(remoteUserId);
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteAnswer(String remoteUserId, RTCSessionDescription answer) async {
    final pc = _connections[remoteUserId];
    if (pc == null) return;
    await pc.setRemoteDescription(answer);
    _remoteDescriptionSet[remoteUserId] = true;
    await _flushPendingCandidates(remoteUserId);
  }

  // Candidates can arrive before setRemoteDescription completes — a real,
  // easy-to-miss WebRTC race. Buffer per remote peer until the remote
  // description is actually set, then flush in order.
  Future<void> addIceCandidate(String remoteUserId, RTCIceCandidate candidate) async {
    if (_remoteDescriptionSet[remoteUserId] != true) {
      (_pendingCandidates[remoteUserId] ??= []).add(candidate);
      return;
    }
    await _connections[remoteUserId]?.addCandidate(candidate);
  }

  Future<void> _flushPendingCandidates(String remoteUserId) async {
    final pending = _pendingCandidates.remove(remoteUserId);
    final pc = _connections[remoteUserId];
    if (pending == null || pc == null) return;
    for (final candidate in pending) {
      await pc.addCandidate(candidate);
    }
  }

  Future<void> closePeer(String remoteUserId) async {
    await _connections.remove(remoteUserId)?.close();
    await remoteRenderers.remove(remoteUserId)?.dispose();
    _pendingCandidates.remove(remoteUserId);
    _remoteDescriptionSet.remove(remoteUserId);
  }

  Future<void> closeAll() async {
    for (final userId in [..._connections.keys]) {
      await closePeer(userId);
    }
  }
}
