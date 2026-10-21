import 'package:ecotrack_app/services/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('token storage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('native stores the session in the OS keychain', () {
      // The test runner is not the web, so the native store is selected.
      expect(createSessionStore(), isA<SecureSessionStore>());
    });

    test('the web store keeps tokens in memory only', () async {
      final store = MemorySessionStore();

      await store.save(accessToken: 'access-1', refreshToken: 'refresh-1');
      expect(await store.readAccessToken(), 'access-1');
      expect(await store.readRefreshToken(), 'refresh-1');

      // Nothing may reach localStorage/shared_preferences: any script on the
      // page can read it, so a single XSS payload would be able to steal a
      // long-lived refresh token.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ecotrack_access_token'), isNull);
      expect(prefs.getString('ecotrack_refresh_token'), isNull);

      await store.clear();
      expect(await store.readAccessToken(), isNull);
      expect(await store.readRefreshToken(), isNull);
    });

    test('clearing the web store leaves nothing behind', () async {
      final store = MemorySessionStore();
      await store.save(accessToken: 'access-1', refreshToken: 'refresh-1');
      await store.clear();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ecotrack_access_token'), isNull);
      expect(prefs.getString('ecotrack_refresh_token'), isNull);
    });
  });
}
