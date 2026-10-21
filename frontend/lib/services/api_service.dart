import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'error_messages.dart';
import 'token_store.dart';

class ApiException implements ApiError {
  @override
  final String message;
  @override
  final int? statusCode;

  /// True for transport failures (offline / timeout) that have no HTTP status.
  final bool isNetworkError;
  ApiException(this.message, [this.statusCode, this.isNetworkError = false]);

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Outcome of a token-refresh attempt. [networkError] must NOT destroy the
/// session: the user is still logged in, the server was just unreachable.
enum RefreshResult { success, invalid, networkError }

class ApiService {
  static const _timeout = Duration(seconds: 60);
  // Sourced from the central helper so there is one source of truth.
  static const _networkMessage = ErrorMessages.network;
  static const _timeoutMessage = ErrorMessages.timeout;

  final http.Client _client;
  late final SessionStore _store;

  /// True when the web refresh token is a first-party HttpOnly cookie, which
  /// requires the app and API to be same-origin (the deployed setup).
  late final bool _useCookieRefresh;

  String? _accessToken;
  String? _refreshToken;
  Future<RefreshResult>? _refreshInFlight;

  /// Called when the session is definitively gone (refresh was rejected), as
  /// opposed to a transient network failure.
  void Function()? onUnauthorized;

  ApiService({http.Client? client, SessionStore? store})
      : _client = client ?? http.Client() {
    _useCookieRefresh = kIsWeb && _isSameOriginWeb();
    _store = store ?? createSessionStore();
  }

  String? get accessToken => _accessToken;
  bool get hasSession => _accessToken != null || _refreshToken != null;
  bool get isWeb => kIsWeb;

  /// The refresh token is held in a browser cookie rather than client state, so
  /// startup must always probe the server (we cannot read the cookie).
  bool get refreshIsCookieBased => _useCookieRefresh;

  static bool _isSameOriginWeb() {
    try {
      return Uri.base.origin == Uri.parse(AppConfig.apiBaseUrl).origin;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> get _platformHeaders =>
      _useCookieRefresh ? const {'X-Client-Platform': 'web'} : const {};

  // ---- Session --------------------------------------------------------------

  Future<void> loadSession() async {
    _accessToken = await _store.readAccessToken();
    _refreshToken = await _store.readRefreshToken();
  }

  Future<void> _saveSession(String accessToken, String? refreshToken) async {
    _accessToken = accessToken;
    if (refreshToken != null) _refreshToken = refreshToken;
    await _store.save(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    await _store.clear();
  }

  // ---- Transport ------------------------------------------------------------

  Future<http.Response> _perform(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}$path',
    ).replace(queryParameters: query);
    final req = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json';
    if (headers != null) req.headers.addAll(headers);
    if (auth && _accessToken != null) {
      req.headers['Authorization'] = 'Bearer $_accessToken';
    }
    if (body != null) req.body = jsonEncode(body);

    http.Response res;
    try {
      final streamed = await _client.send(req).timeout(_timeout);
      res = await http.Response.fromStream(streamed);
    } on TimeoutException catch (e, st) {
      logTechnicalError('$method $path timeout', e, st);
      throw ApiException(_timeoutMessage, null, true);
    } catch (e, st) {
      logTechnicalError('$method $path network', e, st);
      throw ApiException(_networkMessage, null, true);
    }
    return res;
  }

  /// Converts a failed HTTP response into a friendly [ApiException].
  ///
  /// A backend `{"error": "..."}` hint is used only when it passes the central
  /// safety filter; otherwise the status code is mapped to friendly wording.
  /// The raw body/status is logged, never surfaced.
  Never _raise(http.Response res) {
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {}
    final serverMessage =
        (decoded is Map && decoded['error'] is String) ? decoded['error'] as String : null;
    logTechnicalError(
      'HTTP ${res.statusCode}',
      'serverMessage=$serverMessage body=${res.body}',
    );
    throw ApiException(
      ErrorMessages.forStatus(res.statusCode, serverMessage: serverMessage),
      res.statusCode,
    );
  }

  /// One place for every HTTP call: adds headers, refreshes once on 401, and
  /// throws [ApiException] on failure. Returns only 2xx responses.
  Future<http.Response> _sendRaw(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
    Map<String, String>? headers,
    bool allowRefresh = true,
  }) async {
    final res = await _perform(
      method,
      path,
      body: body,
      query: query,
      auth: auth,
      headers: headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return res;

    if (res.statusCode == 401 && auth && allowRefresh) {
      final result = await _refreshAfterUnauthorized();
      switch (result) {
        case RefreshResult.success:
          return _sendRaw(
            method,
            path,
            body: body,
            query: query,
            auth: auth,
            headers: headers,
            allowRefresh: false,
          );
        case RefreshResult.invalid:
          onUnauthorized?.call();
          throw ApiException(ErrorMessages.unauthorized, 401);
        case RefreshResult.networkError:
          throw ApiException(_networkMessage, null, true);
      }
    }
    _raise(res);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    final res = await _sendRaw(
      method,
      path,
      body: body,
      query: query,
      auth: auth,
      headers: headers,
    );
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {}
    return decoded;
  }

  /// For endpoints that return a JSON object.
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    final decoded = await _send(
      method,
      path,
      body: body,
      query: query,
      auth: auth,
      headers: headers,
    );
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  /// For endpoints that return a JSON array.
  Future<List<dynamic>> requestList(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    final decoded = await _send(
      method,
      path,
      body: body,
      query: query,
      auth: auth,
      headers: headers,
    );
    return decoded is List ? decoded : const [];
  }

  /// For endpoints that return a raw text body (e.g. CSV export).
  Future<String> requestText(
    String method,
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final res = await _sendRaw(method, path, query: query, auth: auth);
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  /// For endpoints that return binary content (e.g. PDF export).
  Future<List<int>> requestBytes(
    String method,
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final res = await _sendRaw(method, path, query: query, auth: auth);
    return res.bodyBytes;
  }

  // ---- Token refresh --------------------------------------------------------

  /// Shared by every concurrent 401 so the refresh endpoint is called once.
  Future<RefreshResult> _refreshAfterUnauthorized() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<RefreshResult> _doRefresh() async {
    // Cookie-based web has no stored token; native (and cross-origin web) must
    // have a stored refresh token.
    if (!_useCookieRefresh && _refreshToken == null) {
      return RefreshResult.invalid;
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/auth/refresh');
    final req = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json';
    if (_useCookieRefresh) {
      req.headers['X-Client-Platform'] = 'web';
    } else {
      req.body = jsonEncode({'refresh_token': _refreshToken});
    }

    http.Response res;
    try {
      final streamed = await _client.send(req).timeout(_timeout);
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      return RefreshResult.networkError;
    } catch (_) {
      return RefreshResult.networkError;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        await _saveSession(
          data['access_token'] as String,
          data['refresh_token'] as String?,
        );
        return RefreshResult.success;
      } catch (_) {
        return RefreshResult.networkError;
      }
    }
    if (res.statusCode == 401) {
      await clearSession();
      return RefreshResult.invalid;
    }
    return RefreshResult.networkError;
  }

  // ---- Auth -----------------------------------------------------------------

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password, {
    bool termsAccepted = false,
  }) async {
    final data = await request(
      'POST',
      '/api/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'terms_accepted': termsAccepted,
      },
      auth: false,
      headers: _platformHeaders,
    );
    await _saveSession(
      data['access_token'] as String,
      data['refresh_token'] as String?,
    );
    return data['user'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await request(
      'POST',
      '/api/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
      headers: _platformHeaders,
    );
    await _saveSession(
      data['access_token'] as String,
      data['refresh_token'] as String?,
    );
    return data['user'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> me() async {
    final data = await request('GET', '/api/auth/me');
    return data['user'] as Map<String, dynamic>;
  }

  /// Best-effort server logout (revokes the refresh token / clears the cookie),
  /// then always clears local state.
  Future<void> logout() async {
    try {
      if (_useCookieRefresh) {
        await _perform(
          'POST',
          '/api/auth/logout',
          auth: false,
          headers: const {'X-Client-Platform': 'web'},
        );
      } else if (_refreshToken != null) {
        await _perform(
          'POST',
          '/api/auth/logout',
          auth: false,
          body: {'refresh_token': _refreshToken},
        );
      }
    } catch (_) {
      // Offline logout still clears the local session.
    }
    await clearSession();
  }

  Future<void> deleteAccount() async {
    await request('DELETE', '/api/auth/account');
  }

  /// Starts a password reset. Returns the reset token when the backend is in
  /// debug/demo mode (no email delivery configured), otherwise null.
  Future<String?> forgotPassword(String email) async {
    final data = await request(
      'POST',
      '/api/auth/forgot-password',
      body: {'email': email},
      auth: false,
    );
    return data['reset_token'] as String?;
  }

  /// Completes a password reset with the token from [forgotPassword].
  Future<void> resetPassword(String token, String password) async {
    await request(
      'POST',
      '/api/auth/reset-password',
      body: {'token': token, 'password': password},
      auth: false,
    );
  }

  /// Changes the password of the signed-in user. Invalidates existing tokens,
  /// so callers should log out (or re-authenticate) afterwards.
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await request(
      'POST',
      '/api/auth/change-password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }
}
