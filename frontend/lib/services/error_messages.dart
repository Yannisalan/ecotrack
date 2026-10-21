import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Central, single source of truth for every message a user can see when
/// something goes wrong.
///
/// Rules:
/// * Never surface a raw exception, stack trace, status code, JSON dump or URL.
/// * Polite, short, calm, no jargon, no blame, and always say what to do next.
///
/// The technical detail is logged (see [logTechnicalError]) and never shown.
///
/// Usage:
/// ```dart
/// try {
///   await api.loadSomething();
/// } catch (e, st) {
///   logTechnicalError('loadSomething', e, st);
///   ecoSnack(context, friendlyError(e), error: true);
/// }
/// ```
class ErrorMessages {
  const ErrorMessages._();

  // ---- Network -------------------------------------------------------------
  static const network =
      "Sorry, we couldn't connect. Please check your internet and try again.";
  static const timeout =
      'This is taking longer than expected. Please try again.';

  // ---- HTTP status ---------------------------------------------------------
  static const badRequest =
      "Sorry, we couldn't process that request. Please check your details and try again.";
  static const unauthorized = 'Your session has expired. Please log in again.';
  static const loginFailed = 'Incorrect email or password. Please try again.';
  static const forbidden = "Sorry, you don't have permission to do that.";
  static const notFound =
      "Sorry, we couldn't find what you were looking for.";
  static const conflict = "That didn't work because it already exists.";
  static const tooManyRequests =
      'Too many attempts. Please wait a moment and try again.';
  static const serverError =
      'Sorry, we encountered an error on our side. Please try again in a moment.';

  // ---- Fallbacks -----------------------------------------------------------
  static const unknown = 'Sorry, something went wrong. Please try again.';
  static const unexpected =
      'Sorry, we ran into a problem. Please try again.';

  /// Maps a status code to a friendly message, consulting a trusted backend
  /// hint (already user-facing) when the endpoint provides one.
  static String forStatus(int? status, {String? serverMessage}) {
    final hint = sanitize(serverMessage);
    switch (status) {
      case 400:
        return hint ?? badRequest;
      case 401:
        return hint ?? unauthorized;
      case 403:
        return forbidden;
      case 404:
        return hint ?? notFound;
      case 409:
        return hint ?? conflict;
      case 422:
        return hint ?? badRequest;
      case 429:
        return tooManyRequests;
      case 500:
      case 502:
      case 503:
      case 504:
        return serverError;
      default:
        if (status != null && status >= 500 && status < 600) return serverError;
        if (status != null && status >= 400 && status < 500) {
          return hint ?? badRequest;
        }
        return hint ?? unknown;
    }
  }

  /// Returns [message] only if it looks safe/curated for humans; otherwise null
  /// so the caller falls back to a generic friendly message.
  static String? sanitize(String? message) {
    if (message == null) return null;
    final m = message.trim();
    if (m.isEmpty) return null;

    final lower = m.toLowerCase();
    // Reject anything that smells technical, regardless of origin.
    const banned = [
      'exception',
      'traceback',
      'stack trace',
      'sqlalchemy',
      'psycopg',
      'sqlstate',
      'internal server error',
      'bad gateway',
      'service unavailable',
      'gateway timeout',
      'socketexception',
      'formatexception',
      'null',
      'http://',
      'https://',
      'statuscode',
      '/api/',
    ];
    for (final b in banned) {
      if (lower == b || lower.contains(b)) return null;
    }
    // Reject raw status-code phrasing like "Something went wrong (500)".
    if (RegExp(r'\(\s*\d{3}\s*\)').hasMatch(m)) return null;
    if (RegExp(r'^\s*\d{3}\s*$').hasMatch(m)) return null;
    // Reject very long blobs (likely a dump).
    if (m.length > 220) return null;
    return m;
  }
}

/// Turns any error into a friendly, user-safe message.
///
/// Order of precedence:
/// 1. [ApiException] / network / timeout errors carry an already-friendly
///    message (produced by the API layer) — used as-is.
/// 2. A sanitized backend hint, when present and safe.
/// 3. Status-code mapping.
/// 4. A generic fallback for anything unexpected.
String friendlyError(Object? error) {
  if (error == null) return ErrorMessages.unknown;

  // The API layer already normalises every transport/HTTP error into a
  // friendly [ApiException]; respect its message and status.
  if (error is ApiError) {
    if (error.statusCode != null) {
      return ErrorMessages.forStatus(
        error.statusCode,
        serverMessage: error.message,
      );
    }
    return ErrorMessages.sanitize(error.message) ?? ErrorMessages.unknown;
  }

  if (error is TimeoutException) return ErrorMessages.timeout;
  if (error is SocketException) return ErrorMessages.network;
  if (error is HttpException) return ErrorMessages.network;
  if (error is FormatException) return ErrorMessages.unknown;

  // Plain string (e.g. a provider that stored `e.message`).
  if (error is String) {
    return ErrorMessages.sanitize(error) ?? ErrorMessages.unknown;
  }

  return ErrorMessages.unexpected;
}

/// Minimal contract so the helper does not need to import the API layer
/// (which would create a cycle). [ApiException] implements this.
abstract class ApiError implements Exception {
  String get message;
  int? get statusCode;
}

/// Logs the real technical detail for developers. Never shown to the user.
void logTechnicalError(String context, Object error, [StackTrace? stack]) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[EcoTrack][$context] $error');
    if (stack != null) {
      // ignore: avoid_print
      print(stack);
    }
  }
}
