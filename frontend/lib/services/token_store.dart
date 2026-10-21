import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the session across app restarts.
///
/// Platform-appropriate by design:
/// - Native (Android/iOS/desktop): both tokens live in the OS keychain/keystore
///   via flutter_secure_storage.
/// - Web: the refresh token is an HttpOnly cookie the browser manages, so it is
///   never stored here. The short-lived access token is kept in memory only,
///   which keeps it out of reach of any injected script.
///
/// The web client never writes a token to localStorage/shared_preferences:
/// anything stored there is readable by any script that runs on the page, so a
/// single XSS payload would be enough to steal a long-lived refresh token and
/// keep using it after the tab is closed. See docs/SECURITY_NOTES.md for the
/// trade-off this implies for a cross-origin web deployment.
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

/// In-memory store used on the web.
///
/// Nothing is written to disk: the refresh token is a first-party HttpOnly
/// cookie the browser sends on its own, and the access token lives only in
/// this process. A cross-origin web deployment (where no first-party cookie
/// is available) keeps both in memory, so the user signs in again after a
/// page reload instead of a refresh token being persisted where a script
/// could read it.
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

/// Native -> OS keychain. Web -> in-memory only, never localStorage.
SessionStore createSessionStore() {
  if (!kIsWeb) return SecureSessionStore();
  return MemorySessionStore();
}
