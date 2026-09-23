import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'package:social_app/core/constants/api_constants.dart';
import 'package:social_app/core/storage/token_storage.dart';

class SocketEvent {
  const SocketEvent(this.name, this.data);

  final String name;
  final Map<String, dynamic> data;
}

/// Thin wrapper around a single long-lived Socket.IO connection, exposing a
/// generic event stream rather than one typed stream per event or a raw
/// Socket via getIt — keeps consumers (CallRepository, and eventually chat
/// realtime) decoupled from socket_io_client types, the same way Dio is
/// hidden behind repositories rather than handed out directly.
class SocketService {
  SocketService(this._tokenStorage);

  final TokenStorage _tokenStorage;
  sio.Socket? _socket;
  final _eventsController = StreamController<SocketEvent>.broadcast();

  Stream<SocketEvent> get events => _eventsController.stream;
  bool get isConnected => _socket?.connected ?? false;

  // Every event the backend's realtime layer currently emits that a mobile
  // consumer might care about. Add to this list as new server events are
  // wired up client-side — the server doesn't need to know this list exists.
  static const _subscribedEvents = [
    'call:started',
    'call:incoming',
    'call:participant-joined',
    'call:declined',
    'call:participant-left',
    'call:ended',
    'call:offer',
    'call:answer',
    'call:ice-candidate',
    'call:error',
    'typing:update',
    'message:new',
    'message:reaction',
    'message:reaction-removed',
    'conversation:member-added',
    'conversation:member-removed',
  ];

  void connect() {
    final existing = _socket;
    if (existing != null) {
      // A handshake rejected for an expired token isn't retried by
      // Socket.IO itself, and the token gets refreshed by the next REST
      // call — so when auth state re-fires connect(), retry with the
      // (auth callback re-reads the) current token rather than staying dead.
      if (!existing.connected) existing.connect();
      return;
    }
    final socket = sio.io(
      ApiConstants.appUrl,
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          // Callback form, not a static map: a reconnect long after the
          // initial connect() call must read the CURRENT (possibly
          // refreshed) access token, not one captured at connect time.
          // Matches the backend's socketAuthMiddleware reading
          // socket.handshake.auth.token.
          .setAuthFn(
            (callback) => callback({'token': _tokenStorage.current?.accessToken}),
          )
          .build(),
    );
    socket.onConnect((_) {
      if (kDebugMode) debugPrint('[socket] connected');
    });
    socket.onDisconnect((reason) {
      if (kDebugMode) debugPrint('[socket] disconnected: $reason');
    });
    socket.onConnectError((error) {
      if (kDebugMode) debugPrint('[socket] connect error: $error');
    });
    for (final event in _subscribedEvents) {
      socket.on(event, (data) {
        if (kDebugMode && !event.startsWith('call:ice')) debugPrint('[socket] <- $event');
        _eventsController.add(
          SocketEvent(event, data is Map ? Map<String, dynamic>.from(data) : const {}),
        );
      });
    }
    _socket = socket;
    socket.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void emit(String event, Map<String, dynamic> payload) {
    _socket?.emit(event, payload);
  }
}
