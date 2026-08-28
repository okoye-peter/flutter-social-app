import 'dart:async';

/// Lets DioClient announce that a session died (refresh failed / no refresh
/// token) without depending on AuthBloc directly — AuthBloc listens and
/// drives the router redirect to the login screen.
class AuthSessionNotifier {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get onSessionExpired => _controller.stream;

  void notifySessionExpired() => _controller.add(null);

  void dispose() => _controller.close();
}
