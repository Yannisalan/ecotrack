import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const EcoTrackApp());
}

class EcoTrackApp extends StatelessWidget {
  const EcoTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) =>
              AuthProvider(ctx.read<ApiService>())..restoreSession(),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider()..load(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => 
        MaterialApp(
          title: 'EcoTrack',
          debugShowCheckedModeBanner: false,
          theme: EcoTheme.light(),
          darkTheme: EcoTheme.dark(),
          themeMode: settings.themeMode,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                // Android: icon color
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                // iOS: describes the background, so it's the opposite
                statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                // Optional: same idea for the Android nav bar
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
            ),
            child: child!,
            );
          },
          home: const AuthGate(),
        ),
      ),
    );
  }
}

/// Decides what to show: splash while checking the saved session, then home or
/// login. A transient startup failure shows a retry instead of logging out.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    switch (auth.status) {
      case AuthStatus.unknown:
        if (auth.restoreError != null) {
          return _RestoreError(
            message: auth.restoreError!,
            onRetry: () => auth.retryRestore(),
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        return const AppShellProviders();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

class _RestoreError extends StatelessWidget {
  const _RestoreError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
              TextButton(
                onPressed: () => context.read<AuthProvider>().logout(),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
