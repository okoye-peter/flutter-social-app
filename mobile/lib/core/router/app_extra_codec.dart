import 'dart:convert';

/// Passes `GoRouterState.extra` through unchanged instead of letting
/// go_router attempt to `jsonEncode` it.
///
/// go_router reports the current route (including `extra`) back to its own
/// route-information provider after every navigation, and re-decodes it on
/// every `refreshListenable` tick (see `GoRouterRefreshStream`, which fires
/// on *every* `AuthBloc` state change). Without a codec it tries to
/// JSON-encode `extra`; our `extra` payloads (`RegistrationDraft`,
/// `PostModel`, `StoryViewerArgs`) aren't JSON-encodable, so that silently
/// fails and `extra` is replaced with `null` on the next reparse — which
/// then crashes any route that force-casts `state.extra`. Since this app
/// never needs `extra` to survive real process-death restoration or a web
/// URL, round-tripping the same object reference is sufficient and avoids
/// the crash entirely.
class AppExtraCodec extends Codec<Object?, Object?> {
  const AppExtraCodec();

  @override
  Converter<Object?, Object?> get encoder => const _IdentityConverter();

  @override
  Converter<Object?, Object?> get decoder => const _IdentityConverter();
}

class _IdentityConverter extends Converter<Object?, Object?> {
  const _IdentityConverter();

  @override
  Object? convert(Object? input) => input;
}
