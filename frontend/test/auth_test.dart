import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ecotrack_app/providers/auth_provider.dart';
import 'package:ecotrack_app/services/api_service.dart';
import 'package:ecotrack_app/services/token_store.dart';

/// In-memory [SessionStore] so tests never touch a keychain or disk.
class FakeStore implements SessionStore {
  String? access;
  String? refresh;

  FakeStore({this.access, this.refresh});

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> save({
    required String accessToken,
    String? refreshToken,
  }) async {
    access = accessToken;
    if (refreshToken != null) refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

http.Response _json(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

String? _bearer(http.Request req) => req.headers['Authorization'];

void main() {
  test('login stores access and refresh tokens', () async {
    final store = FakeStore();
    final client = MockClient((req) async {
      expect(req.url.path, '/api/auth/login');
      return _json({
        'access_token': 'a1',
        'refresh_token': 'r1',
        'user': {'name': 'Alex'},
      }, 200);
    });
    final api = ApiService(client: client, store: store);

    final user = await api.login('a@b.com', 'secret123');

    expect(user['name'], 'Alex');
    expect(store.access, 'a1');
    expect(store.refresh, 'r1');
  });

  test('restore with no stored session skips the network', () async {
    var called = false;
    final client = MockClient((req) async {
      called = true;
      return _json({}, 500);
    });
    final provider = AuthProvider(ApiService(client: client, store: FakeStore()));

    await provider.restoreSession();

    expect(provider.status, AuthStatus.unauthenticated);
    expect(called, isFalse);
  });

  test('restore authenticates when the access token is valid', () async {
    final store = FakeStore(access: 'a1', refresh: 'r1');
    final client = MockClient((req) async {
      if (req.url.path == '/api/auth/me') {
        return _json({
          'user': {'name': 'Alex'},
        }, 200);
      }
      return _json({'error': 'unexpected'}, 500);
    });
    final provider = AuthProvider(ApiService(client: client, store: store));

    await provider.restoreSession();

    expect(provider.status, AuthStatus.authenticated);
    expect(provider.userName, 'Alex');
  });

  test('restore refreshes an expired access token and persists new ones',
      () async {
    final store = FakeStore(access: 'old', refresh: 'r1');
    var meCalls = 0;
    final client = MockClient((req) async {
      if (req.url.path == '/api/auth/me') {
        meCalls++;
        if (_bearer(req) == 'Bearer new') {
          return _json({
            'user': {'name': 'Alex'},
          }, 200);
        }
        return _json({'error': 'Token has expired'}, 401);
      }
      if (req.url.path == '/api/auth/refresh') {
        expect(jsonDecode(req.body)['refresh_token'], 'r1');
        return _json({'access_token': 'new', 'refresh_token': 'r2'}, 200);
      }
      return _json({'error': 'unexpected'}, 500);
    });
    final provider = AuthProvider(ApiService(client: client, store: store));

    await provider.restoreSession();

    expect(provider.status, AuthStatus.authenticated);
    expect(meCalls, 2);
    expect(store.access, 'new');
    expect(store.refresh, 'r2');
  });

  test('restore logs out when the refresh token is rejected', () async {
    final store = FakeStore(access: 'old', refresh: 'r1');
    final client = MockClient((req) async {
      if (req.url.path == '/api/auth/me') {
        return _json({'error': 'Token has expired'}, 401);
      }
      if (req.url.path == '/api/auth/refresh') {
        return _json({'error': 'Token has been revoked'}, 401);
      }
      return _json({'error': 'unexpected'}, 500);
    });
    final provider = AuthProvider(ApiService(client: client, store: store));

    await provider.restoreSession();

    expect(provider.status, AuthStatus.unauthenticated);
    expect(store.access, isNull);
    expect(store.refresh, isNull);
  });

  test('restore keeps the session on a network error', () async {
    final store = FakeStore(access: 'a1', refresh: 'r1');
    final client = MockClient((req) async => throw Exception('no network'));
    final provider = AuthProvider(ApiService(client: client, store: store));

    await provider.restoreSession();

    expect(provider.status, AuthStatus.unknown);
    expect(provider.restoreError, isNotNull);
    expect(store.access, 'a1');
    expect(store.refresh, 'r1');
  });

  test('a network error during refresh does not log the user out', () async {
    final store = FakeStore(access: 'old', refresh: 'r1');
    final client = MockClient((req) async {
      if (req.url.path == '/api/auth/me') {
        return _json({'error': 'Token has expired'}, 401);
      }
      if (req.url.path == '/api/auth/refresh') {
        throw Exception('no network');
      }
      return _json({'error': 'unexpected'}, 500);
    });
    final provider = AuthProvider(ApiService(client: client, store: store));

    await provider.restoreSession();

    expect(provider.status, AuthStatus.unknown);
    expect(store.access, 'old');
    expect(store.refresh, 'r1');
  });

  test('concurrent 401s trigger a single refresh', () async {
    final store = FakeStore(access: 'old', refresh: 'r1');
    var refreshCalls = 0;
    final client = MockClient((req) async {
      if (req.url.path == '/api/auth/refresh') {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _json({'access_token': 'new', 'refresh_token': 'r2'}, 200);
      }
      if (req.url.path == '/api/protected') {
        if (_bearer(req) == 'Bearer new') return _json({'ok': true}, 200);
        return _json({'error': 'Token has expired'}, 401);
      }
      return _json({'error': 'unexpected'}, 500);
    });
    final api = ApiService(client: client, store: store);
    await api.loadSession();

    final results = await Future.wait([
      api.request('GET', '/api/protected'),
      api.request('GET', '/api/protected'),
    ]);

    expect(results.every((r) => r['ok'] == true), isTrue);
    expect(refreshCalls, 1);
  });

  test('logout clears the local session', () async {
    final store = FakeStore(access: 'a1', refresh: 'r1');
    final client = MockClient((req) async {
      if (req.url.path == '/api/auth/logout') {
        return _json({'message': 'Logged out'}, 200);
      }
      return _json({'error': 'unexpected'}, 500);
    });
    final api = ApiService(client: client, store: store);
    await api.loadSession();

    await api.logout();

    expect(store.access, isNull);
    expect(store.refresh, isNull);
  });

  test('logout clears the local session even when the server is unreachable',
      () async {
    final store = FakeStore(access: 'a1', refresh: 'r1');
    final client = MockClient((req) async => throw Exception('no network'));
    final api = ApiService(client: client, store: store);
    await api.loadSession();

    await api.logout();

    expect(store.access, isNull);
    expect(store.refresh, isNull);
  });

  test('forgotPassword returns the reset token when the backend echoes it',
      () async {
    final store = FakeStore();
    final client = MockClient((req) async {
      expect(req.method, 'POST');
      expect(req.url.path, '/api/auth/forgot-password');
      expect(jsonDecode(req.body)['email'], 'a@b.com');
      expect(_bearer(req), isNull); // unauthenticated
      return _json({'message': 'ok', 'reset_token': 'tok-123'}, 200);
    });
    final api = ApiService(client: client, store: store);

    expect(await api.forgotPassword('a@b.com'), 'tok-123');
  });

  test('forgotPassword returns null when no token is echoed', () async {
    final store = FakeStore();
    final client = MockClient(
      (req) async => _json({'message': 'If that email is registered...'}, 200),
    );
    final api = ApiService(client: client, store: store);

    expect(await api.forgotPassword('nobody@b.com'), isNull);
  });

  test('resetPassword posts the token and new password', () async {
    final store = FakeStore();
    final client = MockClient((req) async {
      expect(req.url.path, '/api/auth/reset-password');
      final body = jsonDecode(req.body);
      expect(body['token'], 'tok-123');
      expect(body['password'], 'newsecret99');
      return _json({'message': 'Password has been reset.'}, 200);
    });
    final api = ApiService(client: client, store: store);

    await api.resetPassword('tok-123', 'newsecret99');
  });

  test('changePassword logs out (the server invalidated every token)', () async {
    final store = FakeStore(access: 'a1', refresh: 'r1');
    String? authHeader;
    final client = MockClient((req) async {
      if (req.url.path == '/api/auth/change-password') {
        authHeader = _bearer(req);
        final body = jsonDecode(req.body);
        expect(body['current_password'], 'old-secret');
        expect(body['new_password'], 'new-secret-99');
        return _json({'message': 'Password changed'}, 200);
      }
      if (req.url.path == '/api/auth/logout') {
        return _json({'message': 'Logged out'}, 200);
      }
      return _json({'error': 'unexpected'}, 500);
    });
    final api = ApiService(client: client, store: store);
    await api.loadSession();

    final auth = AuthProvider(api);
    final error = await auth.changePassword('old-secret', 'new-secret-99');

    expect(error, isNull);
    expect(authHeader, 'Bearer a1'); // the call was authenticated
    expect(auth.status, AuthStatus.unauthenticated); // then logged out
    expect(store.access, isNull);
    expect(store.refresh, isNull);
  });

  test('changePassword surfaces the server error and keeps the session',
      () async {
    final store = FakeStore(access: 'a1', refresh: 'r1');
    final client = MockClient((req) async {
      if (req.url.path == '/api/auth/change-password') {
        return _json({'error': 'Current password is incorrect'}, 400);
      }
      return _json({'error': 'unexpected'}, 500);
    });
    final api = ApiService(client: client, store: store);
    await api.loadSession();

    final auth = AuthProvider(api);
    final error = await auth.changePassword('wrong', 'new-secret-99');

    expect(error, 'Current password is incorrect');
    expect(store.access, 'a1'); // not logged out
  });
}
