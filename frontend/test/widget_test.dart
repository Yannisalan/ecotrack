import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecotrack_app/providers/achievements_provider.dart';
import 'package:ecotrack_app/providers/challenges_provider.dart';
import 'package:ecotrack_app/providers/offline_provider.dart';
import 'package:ecotrack_app/screens/achievements_screen.dart';
import 'package:ecotrack_app/screens/calendar_screen.dart';
import 'package:ecotrack_app/screens/challenges_screen.dart';
import 'package:ecotrack_app/services/api_service.dart';
import 'package:ecotrack_app/services/offline.dart';

Widget _wrap(Widget child, {List<ChangeNotifierProvider> providers = const []}) =>
    MultiProvider(
      providers: [Provider<ApiService>(create: (_) => ApiService()), ...providers],
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('sanity test', (WidgetTester tester) async {
    expect(1 + 1, 2);
  });

  testWidgets('AchievementsScreen builds with a provided provider', (
    tester,
  ) async {
    final api = ApiService();
    await tester.pumpWidget(
      _wrap(
        const AchievementsScreen(),
        providers: [
          ChangeNotifierProvider<AchievementsProvider>(
            create: (_) => AchievementsProvider(api),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('Achievements'), findsOneWidget);
  });

  testWidgets('ChallengesScreen builds with a provided provider', (
    WidgetTester tester,
  ) async {
    final api = ApiService();
    await tester.pumpWidget(
      _wrap(
        const ChallengesScreen(),
        providers: [
          ChangeNotifierProvider<ChallengesProvider>(
            create: (_) => ChallengesProvider(api),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('Challenges'), findsWidgets);
  });

  testWidgets('CalendarScreen provides its own state from ApiService', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const CalendarScreen()));
    await tester.pump();
    expect(find.text('Sustainability Calendar'), findsOneWidget);
  });

  testWidgets('OfflineQueue persists queued activities', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await OfflineQueue.add({
      'category': 'waste',
      'type': 'recycling',
      'quantity': 0.5,
      'date': '2026-01-01',
    });
    final items = await OfflineQueue.load();
    expect(items.length, 1);
    expect(items.first['category'], 'waste');
  });

  testWidgets('OfflineProvider counts queued activities', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'offline_activity_queue': jsonEncode([
        {'category': 'transport', 'type': 'bus', 'quantity': 10, 'date': '2026-01-01'},
      ]),
    });
    final provider = OfflineProvider(ApiService());
    await provider.refreshCount();
    expect(provider.pending, 1);
  });
}
