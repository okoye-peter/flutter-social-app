import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:social_app/models/auth_tokens.dart';

class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  AuthTokens? _cache;

  AuthTokens? get current => _cache;

  Future<AuthTokens?> load() async {
    try {
      final results = await Future.wait([
        _storage.read(key: _accessTokenKey),
        _storage.read(key: _refreshTokenKey),
      ]);
      final accessToken = results[0];
      final refreshToken = results[1];

      if (accessToken == null || refreshToken == null) {
        _cache = null;
        return null;
      }

      _cache = AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
      return _cache;
    } catch (_) {
      // Keystore/Keychain entry can become unreadable (e.g. after biometric
      // enrollment changes on Android) — treat as no saved session rather
      // than crashing app startup.
      _cache = null;
      return null;
    }
  }

  Future<void> save(AuthTokens tokens) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: tokens.accessToken),
      _storage.write(key: _refreshTokenKey, value: tokens.refreshToken),
    ]);
    _cache = tokens;
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
    _cache = null;
  }
}
