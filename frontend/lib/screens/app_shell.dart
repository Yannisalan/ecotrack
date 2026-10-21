import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/achievements_provider.dart';
import '../providers/challenges_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/goals_provider.dart';
import '../providers/insights_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/offline_provider.dart';
import '../services/api_service.dart';
import '../services/stats_api.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/eco_widgets.dart';
import 'analytics_screen.dart';
import 'goals_screen.dart';
import 'home_screen.dart';
import 'log_activity_sheet.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'recommendations_screen.dart';

/// Signature for the shared "log an activity" flow, exposed to tab screens so
/// a save refreshes the dashboard and the streak in one place.
typedef LogActionHandler = Future<void> Function({String? category});

const _subtitles = [
  'Overview',
  'Analytics',
  'Insights & Habits',
  'Eco Goals',
  'Profile & Settings',
];

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
      context.read<GoalsProvider>().load();
      context.read<AchievementsProvider>().load();
      context.read<ChallengesProvider>().load();
      context.read<InsightsProvider>().load();
      context.read<NotificationsProvider>().load();
      context.read<OfflineProvider>().refreshCount();
      _loadStreak();
    });
  }

  Future<void> _loadStreak() async {
    try {
      final data = await context.read<ApiService>().getStreak();
      if (!mounted) return;
      setState(() => _streak = (data['current_streak'] as num?)?.toInt() ?? 0);
    } on ApiException {
      // Streak is decorative; ignore failures quietly.
    }
  }

  Future<void> _logActivity({String? category}) async {
    final saved = await showLogActivitySheet(context, category: category);
    if (!mounted) return;
    if (saved == true) {
      await Future.wait([
        context.read<DashboardProvider>().load(),
        context.read<AchievementsProvider>().load(),
        context.read<ChallengesProvider>().load(),
        context.read<InsightsProvider>().load(),
        context.read<NotificationsProvider>().load(),
        _loadStreak(),
      ]);
    } else if (saved == 'offline') {
      await context.read<OfflineProvider>().refreshCount();
      if (mounted) {
        ecoSnack(
          context,
          'Saved offline — will sync when you are back online.',
        );
      }
    }
  }

  Future<void> _openNotifications() async {
    final provider = context.read<NotificationsProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const NotificationsScreen(),
        ),
      ),
    );
    if (mounted) await provider.load();
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationsProvider>().unread;
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            subtitle: _subtitles[_index],
            streak: _streak,
            unread: unread,
            onNotificationsTap: _openNotifications,
            onProfileTap: () => setState(() => _index = 4),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                HomeScreen(onLogAction: _logActivity),
                const AnalyticsScreen(),
                RecommendationsScreen(onLogAction: _logActivity),
                const GoalsScreen(),
                const ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: LogActionFab(onTap: () => _logActivity()),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: EcoBottomNav(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// Wraps the shell with the shared dashboard + goals state.
class AppShellProviders extends StatelessWidget {
  const AppShellProviders({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiService>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DashboardProvider>(
          create: (_) => DashboardProvider(api),
        ),
        ChangeNotifierProvider<GoalsProvider>(
          create: (_) => GoalsProvider(api),
        ),
        ChangeNotifierProvider<AchievementsProvider>(
          create: (_) => AchievementsProvider(api),
        ),
        ChangeNotifierProvider<ChallengesProvider>(
          create: (_) => ChallengesProvider(api),
        ),
        ChangeNotifierProvider<InsightsProvider>(
          create: (_) => InsightsProvider(api),
        ),
        ChangeNotifierProvider<NotificationsProvider>(
          create: (_) => NotificationsProvider(api),
        ),
        ChangeNotifierProvider<OfflineProvider>(
          create: (_) => OfflineProvider(api),
        ),
      ],
      child: const AppShell(),
    );
  }
}
