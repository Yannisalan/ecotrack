import 'dart:async';

import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/error_messages.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final ApiService api;
  AuthStatus status = AuthStatus.unknown;
  Map<String, dynamic>? user;

  /// Set when startup restoration fails for a transient (non-auth) reason, so
  /// the UI can offer a retry instead of kicking the user back to login.
  String? restoreError;

  AuthProvider(this.api) {
    api.onUnauthorized = _handleExpired;
  }

  String get userName => (user?['name'] as String?) ?? '';

  /// Runs once at startup. Keeps the session on a network error (never logs the
  /// user out just because the server was briefly unreachable).
  Future<void> restoreSession() async {
    await api.loadSession();

    // When the refresh token is an HttpOnly cookie we cannot inspect it, so we
    // always probe. Otherwise skip the round trip if nothing is stored.
    if (!api.refreshIsCookieBased && !api.hasSession) {
      status = AuthStatus.unauthenticated;
      restoreError = null;
      notifyListeners();
      return;
    }

    status = AuthStatus.unknown;
    restoreError = null;
    notifyListeners();

    try {
      // me() transparently refreshes an expired access token. A 401 that
      // reaches us here means the refresh token was rejected too.
      user = await api.me();
      status = AuthStatus.authenticated;
      restoreError = null;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await api.clearSession();
        user = null;
        status = AuthStatus.unauthenticated;
        restoreError = null;
      } else {
        // Transient: keep the stored session and let the user retry.
        status = AuthStatus.unknown;
        restoreError = friendlyError(e);
      }
    }
    notifyListeners();
  }

  Future<void> retryRestore() => restoreSession();

  /// Returns null on success, or an error message to show.
  Future<String?> login(String email, String password) async {
    try {
      user = await api.login(email, password);
      status = AuthStatus.authenticated;
      restoreError = null;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      // Wrong credentials get a specific, expected message.
      if (e.statusCode == 401) return ErrorMessages.loginFailed;
      return friendlyError(e);
    }
  }

  Future<String?> register(
    String name,
    String email,
    String password, {
    bool termsAccepted = false,
  }) async {
    try {
      user = await api.register(
        name,
        email,
        password,
        termsAccepted: termsAccepted,
      );
      status = AuthStatus.authenticated;
      restoreError = null;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return friendlyError(e);
    }
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    status = AuthStatus.unauthenticated;
    restoreError = null;
    notifyListeners();
  }

  /// Returns null on success, or an error message to show.
  Future<String?> deleteAccount() async {
    try {
      await api.deleteAccount();
    } on ApiException catch (e) {
      return friendlyError(e);
    }
    await logout();
    return null;
  }

  /// Requests a reset token. Returns (error, token): error is non-null on
  /// failure; token is the raw reset token when the backend echoes it (debug
  /// builds without email delivery).
  Future<(String?, String?)> forgotPassword(String email) async {
    try {
      final token = await api.forgotPassword(email);
      return (null, token);
    } on ApiException catch (e) {
      return (friendlyError(e), null);
    }
  }

  /// Returns null on success, or an error message to show.
  Future<String?> resetPassword(String token, String password) async {
    try {
      await api.resetPassword(token, password);
      return null;
    } on ApiException catch (e) {
      return friendlyError(e);
    }
  }

  /// Returns null on success, or an error message to show. On success the
  /// session is dropped because the server invalidated all existing tokens.
  Future<String?> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      await api.changePassword(currentPassword, newPassword);
    } on ApiException catch (e) {
      return friendlyError(e);
    }
    await logout();
    return null;
  }

  /// The session is definitively gone (refresh rejected). Drop local state only;
  /// there is nothing useful to tell the server.
  void _handleExpired() {
    if (status == AuthStatus.unauthenticated) return;
    user = null;
    status = AuthStatus.unauthenticated;
    unawaited(api.clearSession());
    notifyListeners();
  }
}
