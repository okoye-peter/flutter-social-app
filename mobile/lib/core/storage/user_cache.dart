import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_app/models/user_model.dart';

class UserCache {
  UserCache(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'cached_user';

  UserModel? _cache;

  UserModel? get current => _cache;

  UserModel? load() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) {
        _cache = null;
        return null;
      }

      _cache = UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _cache;
    } catch (_) {
      // Cached shape no longer matches UserModel (e.g. after a field change
      // in an app update) — drop it rather than crashing app startup.
      _cache = null;
      return null;
    }
  }

  Future<void> save(UserModel user) async {
    await _prefs.setString(_key, jsonEncode(user.toJson()));
    _cache = user;
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
    _cache = null;
  }
}
