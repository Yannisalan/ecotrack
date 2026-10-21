import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ecotrack_app/services/api_service.dart';
import 'package:ecotrack_app/services/error_messages.dart';

void main() {
  group('ErrorMessages.forStatus', () {
    test('maps each required status to friendly, jargon-free copy', () {
      expect(ErrorMessages.forStatus(400), ErrorMessages.badRequest);
      expect(ErrorMessages.forStatus(401), ErrorMessages.unauthorized);
      expect(ErrorMessages.forStatus(403), ErrorMessages.forbidden);
      expect(ErrorMessages.forStatus(404), ErrorMessages.notFound);
      expect(ErrorMessages.forStatus(409), ErrorMessages.conflict);
      expect(ErrorMessages.forStatus(429), ErrorMessages.tooManyRequests);
      expect(ErrorMessages.forStatus(500), ErrorMessages.serverError);
      expect(ErrorMessages.forStatus(502), ErrorMessages.serverError);
      expect(ErrorMessages.forStatus(503), ErrorMessages.serverError);
      expect(ErrorMessages.forStatus(999), ErrorMessages.unknown);
    });

    test('prefers a safe backend hint for 400/404/409', () {
      expect(
        ErrorMessages.forStatus(
          400,
          serverMessage: 'Sorry, we couldn\'t process that request. '
              'Please check your details and try again.',
        ),
        'Sorry, we couldn\'t process that request. '
        'Please check your details and try again.',
      );
      expect(
        ErrorMessages.forStatus(404, serverMessage: 'Activity not found'),
        'Activity not found',
      );
    });

    test('the conflict wording does not reveal that a record exists', () {
      final message = ErrorMessages.forStatus(409).toLowerCase();
      for (final leak in ['already', 'exists', 'taken', 'registered']) {
        expect(message.contains(leak), isFalse);
      }
    });

    test('ignores technical backend hints and falls back', () {
      expect(
        ErrorMessages.forStatus(
          400,
          serverMessage: 'Invalid category/type. See GET /api/activities/options',
        ),
        ErrorMessages.badRequest,
      );
      expect(
        ErrorMessages.forStatus(400, serverMessage: 'Something went wrong (500).'),
        ErrorMessages.badRequest,
      );
      expect(
        ErrorMessages.forStatus(
          400,
          serverMessage: 'Traceback (most recent call last): sqlalchemy...',
        ),
        ErrorMessages.badRequest,
      );
    });

    test('never echoes a hint for 403/429/5xx', () {
      expect(
        ErrorMessages.forStatus(403, serverMessage: 'forbidden role xyz'),
        ErrorMessages.forbidden,
      );
      expect(
        ErrorMessages.forStatus(429, serverMessage: 'rate limit 10/min'),
        ErrorMessages.tooManyRequests,
      );
      expect(
        ErrorMessages.forStatus(500, serverMessage: 'psycopg error'),
        ErrorMessages.serverError,
      );
    });
  });

  group('friendlyError', () {
    test('null and unknown objects resolve to a generic message', () {
      expect(friendlyError(null), ErrorMessages.unknown);
      expect(friendlyError(Object()), ErrorMessages.unexpected);
    });

    test('transport errors map to network/timeout copy', () {
      expect(friendlyError(TimeoutException('x')), ErrorMessages.timeout);
      expect(friendlyError(const SocketException('x')), ErrorMessages.network);
    });

    test('ApiException uses its status + safe message', () {
      expect(
        friendlyError(ApiException('Activity not found', 404)),
        'Activity not found',
      );
      expect(
        friendlyError(ApiException('raw internal detail', 500)),
        ErrorMessages.serverError,
      );
      expect(
        friendlyError(ApiException(ErrorMessages.network, null, true)),
        ErrorMessages.network,
      );
    });

    test('raw string input is sanitised', () {
      expect(friendlyError('Activity not found'), 'Activity not found');
      expect(
        friendlyError('SocketException: Connection refused'),
        ErrorMessages.unknown,
      );
    });
  });
}
