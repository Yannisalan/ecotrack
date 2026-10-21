import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the session across app restarts.
///
/// Platform-appropriate by design:
/// - Native (Android/iOS/desktop): both tokens live in the OS keychain/keystore
///   via flutter_secure_storage.
/// - Web: the refresh token is an HttpOnly cookie the browser manages, so it is
///   never stored here. The short-lived access token is kept in memory only,
///   which keeps it out of reach of any injected script.
abstract class SessionStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> save({required String accessToken, String? refreshToken});
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  static const _accessKey = 'ecotrack_access_token';
  static const _refreshKey = 'ecotrack_refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> save({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshKey, value: refreshToken);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// In-memory store used when the web refresh token lives in an HttpOnly cookie
/// (same-origin deployment). Nothing is written to disk.
class MemorySessionStore implements SessionStore {
  String? _access;
  String? _refresh;

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> save({
    required String accessToken,
    String? refreshToken,
  }) async {
    _access = accessToken;
    if (refreshToken != null) _refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

/// localStorage-backed store. Used on the web only when cookies are not
/// available (local development, or a cross-origin API host), where the refresh
/// token must be sent in the request body. Client-side storage is XSS-exposed,
/// which is why it is only the fallback and never used for same-origin prod.
class PrefsSessionStore implements SessionStore {
  static const _accessKey = 'ecotrack_access_token';
  static const _refreshKey = 'ecotrack_refresh_token';

  @override
  Future<String?> readAccessToken() async =>
      (await SharedPreferences.getInstance()).getString(_accessKey);

  @override
  Future<String?> readRefreshToken() async =>
      (await SharedPreferences.getInstance()).getString(_refreshKey);

  @override
  Future<void> save({
    required String accessToken,
    String? refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, accessToken);
    if (refreshToken != null) await prefs.setString(_refreshKey, refreshToken);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }
}

/// Native -> OS keychain. Web -> in-memory when the refresh token is a
/// first-party HttpOnly cookie, otherwise localStorage (documented fallback).
SessionStore createSessionStore({bool cookieMode = false}) {
  if (!kIsWeb) return SecureSessionStore();
  return cookieMode ? MemorySessionStore() : PrefsSessionStore();
}
