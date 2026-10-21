import 'package:flutter/foundation.dart';

class AppConfig {
  /// Override at run time, e.g. for a real phone or a deployed backend:
  /// flutter run --dart-define=API_BASE_URL=https://your-backend.example.com
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// PLACEHOLDER: the deployed backend (Render) URL. Replace
  /// `https://YOUR-RENDER-SERVICE.onrender.com` with your real Render service URL
  /// (the `name:` in render.yaml + `.onrender.com`) in frontend/web/vercel.json
  /// (the /api/:path* rewrite destination), so the web app and API stay
  /// same-origin and the refresh cookie stays first-party.
  ///
  /// The web release build uses [Uri.base.origin] (same origin as the rewrite),
  /// so no URL is hard-coded here.

  /// Picks the right address per platform when running against Flask on your PC.
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) {
      // Production web is served same-origin: the Vercel /api/* rewrite proxies
      // to the Render backend, which keeps the refresh cookie first-party (and
      // therefore usable). In debug we talk to the local Flask server directly.
      if (kReleaseMode) return Uri.base.origin;
      return 'http://127.0.0.1:5000'; // Chrome
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5000'; // Android emulator -> host PC
      default:
        return 'http://127.0.0.1:5000'; // iOS simulator (same Mac as Flask)
    }
  }
}
