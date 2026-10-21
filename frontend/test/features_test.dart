import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:ecotrack_app/providers/achievements_provider.dart';
import 'package:ecotrack_app/providers/challenges_provider.dart';
import 'package:ecotrack_app/providers/dashboard_provider.dart';
import 'package:ecotrack_app/providers/insights_provider.dart';
import 'package:ecotrack_app/providers/notifications_provider.dart';
import 'package:ecotrack_app/screens/achievements_screen.dart';
import 'package:ecotrack_app/screens/challenges_screen.dart';
import 'package:ecotrack_app/screens/notifications_screen.dart';
import 'package:ecotrack_app/screens/recommendations_screen.dart';
import 'package:ecotrack_app/services/api_service.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: const {'content-type': 'application/json'},
);

Widget _wrap(Widget child, {List<ChangeNotifierProvider> providers = const []}) =>
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ...providers,
      ],
      child: MaterialApp(home: child),
    );

void main() {
  test('InsightsProvider loads a period and switches it', () async {
    var seenPeriod = '';
    final client = MockClient((req) async {
      if (req.url.path == '/api/insights') {
        seenPeriod = req.url.queryParameters['period'] ?? '';
        return _json({
          'period': seenPeriod,
          'has_data': true,
          'total_co2_kg': 12.5,
          'trend': 'improving',
          'categories': [],
        });
      }
      return _json({'error': 'unexpected'}, 500);
    });
    final provider = InsightsProvider(ApiService(client: client));

    await provider.load();
    expect(seenPeriod, 'week');
    expect(provider.data?['has_data'], true);
    expect(provider.loading, isFalse);

    await provider.setPeriod('month');
    expect(seenPeriod, 'month');
    expect(provider.period, 'month');
    expect(provider.data?['period'], 'month');
  });

  test('NotificationsProvider tracks read, dismiss and preferences', () async {
    var unread = 2;
    final client = MockClient((req) async {
      final path = req.url.path;
      if (path == '/api/notifications' && req.method == 'GET') {
        return _json({
          'notifications': [
            {
              'id': 1,
              'code': 'trend_down',
              'type': 'insight',
              'severity': 'success',
              'title': 'Nice trend',
              'body': 'Down 10%',
              'read': false,
              'created_at': '2026-10-20T10:00:00',
            },
            {
              'id': 2,
              'code': 'log_today',
              'type': 'reminder',
              'severity': 'info',
              'title': 'Log today',
              'body': 'Keep it up',
              'read': false,
              'created_at': '2026-10-20T09:00:00',
            },
          ],
          'unread': unread,
        });
      }
      if (path == '/api/notifications/1/read') {
        unread = 1;
        return _json({'unread': unread});
      }
      if (path == '/api/notifications/2' && req.method == 'DELETE') {
        unread = 0;
        return _json({'unread': unread});
      }
      if (path == '/api/notifications/preferences' && req.method == 'GET') {
        return _json({
          'preferences': {'daily_reminder': true, 'reminder_hour': 19},
        });
      }
      if (path == '/api/notifications/preferences' && req.method == 'PUT') {
        final changes = jsonDecode(req.body) as Map<String, dynamic>;
        return _json({
          'preferences': {
            'daily_reminder': true,
            'reminder_hour': 19,
            ...changes,
          },
        });
      }
      return _json({'error': 'unexpected $path'}, 500);
    });
    final provider = NotificationsProvider(ApiService(client: client));

    await provider.load();
    expect(provider.items.length, 2);
    expect(provider.unread, 2);

    await provider.markRead(1);
    expect(provider.unread, 1);
    expect(provider.items.first['read'], true);

    await provider.dismiss(2);
    expect(provider.items.length, 1);
    expect(provider.unread, 0);

    await provider.loadPreferences();
    expect(provider.preferences?['daily_reminder'], true);

    final ok = await provider.updatePreference('daily_reminder', false);
    expect(ok, isTrue);
    expect(provider.preferences?['daily_reminder'], false);
  });

  testWidgets('NotificationsScreen shows inbox and preference switches', (
    tester,
  ) async {
    final client = MockClient((req) async {
      if (req.url.path == '/api/notifications/preferences') {
        return _json({
          'preferences': {
            'daily_reminder': true,
            'reminder_hour': 19,
            'streak_reminders': true,
            'challenge_nudges': true,
            'trend_alerts': true,
            'achievement_alerts': true,
            'weekly_summary': true,
          },
        });
      }
      return _json({'notifications': const [], 'unread': 0});
    });
    final api = ApiService(client: client);
    await tester.pumpWidget(
      _wrap(
        const NotificationsScreen(),
        providers: [
          ChangeNotifierProvider<NotificationsProvider>(
            create: (_) => NotificationsProvider(api),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('You are all caught up'), findsOneWidget);
    expect(find.text('Reminders & alerts'.toUpperCase()), findsOneWidget);
    expect(find.text('Daily check-in'), findsOneWidget);
  });

  testWidgets('ChallengesScreen shows recent completions', (tester) async {
    final api = ApiService();
    final provider = ChallengesProvider(api)
      ..history = [
        {
          'code': 'daily_log',
          'title': 'Log an activity',
          'period_key': '2026-10-20',
          'reward_points': 10,
          'completed_at': '2026-10-20T10:00:00',
        },
      ]
      ..completedTotal = 3;

    await tester.pumpWidget(
      _wrap(
        const ChallengesScreen(),
        providers: [
          ChangeNotifierProvider<ChallengesProvider>.value(value: provider),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('RECENT COMPLETIONS'), findsOneWidget);
    expect(find.text('3 all time'), findsOneWidget);
    expect(find.text('Log an activity'), findsOneWidget);
  });

  testWidgets('AchievementsScreen renders the challenges category', (
    tester,
  ) async {
    final api = ApiService();
    final provider = AchievementsProvider(api)
      ..achievements = [
        {
          'code': 'challenge_finisher',
          'name': 'Challenge Finisher',
          'description': 'Complete a challenge',
          'icon': 'flag',
          'category': 'challenges',
          'target': 1,
          'progress': 1,
          'earned': true,
        },
      ];

    await tester.pumpWidget(
      _wrap(
        const AchievementsScreen(),
        providers: [
          ChangeNotifierProvider<AchievementsProvider>.value(value: provider),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('CHALLENGES'), findsOneWidget);
    expect(find.text('Challenge Finisher'), findsOneWidget);
  });

  testWidgets('RecommendationsScreen renders the insights summary', (
    tester,
  ) async {
    final api = ApiService();
    final insights = InsightsProvider(api)
      ..data = {
        'has_data': true,
        'total_co2_kg': 12.5,
        'trend': 'improving',
        'change_pct': -12.4,
        'eco_score': {'avg_daily_co2_kg': 2.5},
        'top_category': {'category': 'transport', 'share': 0.62},
        'projection': {'monthly_co2_kg': 54.0, 'annual_tonnes': 0.65},
        'highlights': [
          {'title': 'Down from last period', 'body': 'Your footprint fell.'},
        ],
        'watchouts': [],
      };

    await tester.pumpWidget(
      _wrap(
        RecommendationsScreen(onLogAction: ({String? category}) async {}),
        providers: [
          ChangeNotifierProvider<DashboardProvider>(
            create: (_) => DashboardProvider(api),
          ),
          ChangeNotifierProvider<InsightsProvider>.value(value: insights),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('INSIGHTS'), findsOneWidget);
    expect(find.text('12.5 kg'), findsOneWidget);
    expect(find.textContaining('Biggest source: Mobility'), findsOneWidget);
    expect(find.text('Down from last period'), findsOneWidget);
  });
}
