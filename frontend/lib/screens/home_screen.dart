import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/achievements_provider.dart';
import '../providers/challenges_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/history_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/offline_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/eco_biome.dart';
import '../widgets/eco_meta.dart';
import '../widgets/eco_score_gauge.dart';
import '../widgets/eco_widgets.dart';
import '../widgets/virtual_grove.dart';
import 'achievements_screen.dart';
import 'activity_detail_sheet.dart';
import 'app_shell.dart';
import 'challenges_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onLogAction});

  final LogActionHandler onLogAction;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HistoryProvider _history;
  bool _showBiome = true;

  @override
  void initState() {
    super.initState();
    _history = HistoryProvider(context.read<ApiService>());
    WidgetsBinding.instance.addPostFrameCallback((_) => _history.load());
  }

  @override
  void dispose() {
    _history.dispose();
    super.dispose();
  }

  List<PillarSlice> _pillars(BuildContext context, Map<String, dynamic>? summary) {
    final byCategory =
        (summary?['by_category'] as Map<String, dynamic>?) ?? const {};
    final total = (summary?['total_co2_kg'] as num?)?.toDouble() ?? 0;
    return ecoCategories.map((meta) {
      final entry =
          (byCategory[meta.key] as Map<String, dynamic>?) ?? const {};
      final kg = (entry['co2_kg'] as num?)?.toDouble() ?? 0;
      return PillarSlice(
        label: meta.label,
        color: meta.colorOf(context),
        kg: kg,
        share: total > 0 ? kg / total : 0,
      );
    }).toList();
  }

  Future<void> _log({String? category}) async {
    await widget.onLogAction(category: category);
    await _history.load();
  }

  Future<void> _refreshAll() async {
    final dashboard = context.read<DashboardProvider>();
    final achievements = context.read<AchievementsProvider>();
    final challenges = context.read<ChallengesProvider>();
    final notifications = context.read<NotificationsProvider>();
    await dashboard.load();
    await achievements.load();
    await challenges.load();
    await notifications.load();
    await _history.load();
  }

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final dashboard = context.watch<DashboardProvider>();
    final theme = Theme.of(context);
    final name = context.watch<AuthProvider>().userName;
    final settings = context.watch<SettingsProvider>();
    final summary = dashboard.summary;
    final score = dashboard.score;
    final daily = (summary?['daily'] as List?) ?? const [];
    final todayKg = daily.isEmpty
        ? 0.0
        : ((daily.last as Map)['co2_kg'] as num?)?.toDouble() ?? 0;
    final avgKg = (score?['avg_daily_co2_kg'] as num?)?.toDouble();
    final byCategory =
        (summary?['by_category'] as Map<String, dynamic>?) ?? const {};
    final totalEntries = byCategory.values.fold<int>(
      0,
      (sum, c) => sum + (((c as Map)['entries'] as num?)?.toInt() ?? 0),
    );
    final pillars = _pillars(context, summary);

    if (dashboard.loading && summary == null) {
      return const LoadingState();
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
        children: [
          // Greeting
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, ${name.isNotEmpty ? name.split(' ').first : 'there'} ',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Every green action restores our planet.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: eco.primary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _log(),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Log'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  textStyle: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Smart notifications (server-driven nudges)
          const _NotificationsBanner(),

          // Offline queue status
          const _OfflineBanner(),

          // Impact sanctuary switcher
          Row(
            children: [
              const Expanded(
                child: SectionLabel(
                  label: 'Impact Sanctuary',
                  icon: Icons.auto_awesome,
                ),
              ),
              PillSegmented<bool>(
                options: const [true, false],
                value: _showBiome,
                onChanged: (v) => setState(() => _showBiome = v),
                labelOf: (v) => v ? 'Living Biome' : 'Score Gauge',
              ),
            ],
          ),
          if (_showBiome)
            EcoBiome(pillars: pillars)
          else
            EcoCard(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: EcoScoreGauge(
                  score: score?['score'] as num?,
                  grade: score?['grade'] as String?,
                  pillars: pillars,
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Today's highlights (real numbers)
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Today Logged',
                  value: '+${ecoFormatKg(todayKg)}',
                  unit: 'kg CO₂',
                  note: 'Logged today',
                  icon: Icons.auto_awesome,
                  accent: eco.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Daily Average',
                  value: avgKg == null ? '—' : ecoFormatKg(avgKg),
                  unit: 'kg CO₂',
                  note: avgKg == null
                      ? 'Log to see your average'
                      : 'Per active day (${dashboard.period == 'week' ? '7' : '30'} days)',
                  icon: Icons.trending_up,
                  accent: eco.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Track activity grid
          const SectionLabel(
            label: 'Track Activity',
            icon: Icons.bolt_outlined,
            trailing: null,
          ),
          Row(
            children: ecoCategories.map((meta) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: meta == ecoCategories.last ? 0 : 8,
                  ),
                  child: EcoCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 12,
                    ),
                    onTap: () => _log(category: meta.key),
                    child: Column(
                      children: [
                        TintedIcon(
                          icon: meta.icon,
                          color: meta.colorOf(context),
                          size: 38,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          meta.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${(byCategory[meta.key] as Map?)?['entries'] ?? 0} logged',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: eco.textSecondary,
                            fontSize: 9.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),

          // Grove
          EcoCard(
            child: VirtualGrove(activities: totalEntries),
          ),
          const SizedBox(height: 22),

          // Achievements entry (real progress, opens detail screen)
          _AchievementsCard(
            onTap: () {
              final provider = context.read<AchievementsProvider>();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: provider,
                    child: const AchievementsScreen(),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Challenges entry (real progress, opens detail screen)
          _ChallengesCard(
            onTap: () {
              final provider = context.read<ChallengesProvider>();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: provider,
                    child: const ChallengesScreen(),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 22),

          // SDG strip (real footprint share)
          _SdgStrip(summary: summary),
          const SizedBox(height: 22),

          // Activity feed
          Row(
            children: [
              const Expanded(
                child: SectionLabel(
                  label: 'Activity History',
                  icon: Icons.history,
                ),
              ),
              Text(
                settings.units == UnitSystem.metric ? '' : 'imperial',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: eco.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 34,
            child: ListenableBuilder(
              listenable: _history,
              builder: (context, _) => ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip(null, 'All'),
                  ...ecoCategories.map(
                    (c) => _filterChip(c.key, c.label),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: _history,
            builder: (context, _) {
              if (_history.loading && _history.items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(28),
                  child: LoadingState(),
                );
              }
              if (_history.error != null && _history.items.isEmpty) {
                return _EmptyFeed(
                  message: _history.error!,
                  onLog: () => _log(),
                );
              }
              if (_history.items.isEmpty) {
                return _EmptyFeed(
                  message: 'No activities found for this filter.',
                  onLog: () => _log(),
                );
              }
              return Column(
                children: _history.items.take(7).map((activity) {
                  final meta = ecoCategory(activity['category'] as String?);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: EcoCard(
                      padding: const EdgeInsets.all(12),
                      onTap: () => showActivityDetailSheet(
                        context,
                        activity: activity,
                        onChanged: _refreshAll,
                      ),
                      child: Row(
                        children: [
                          TintedIcon(
                            icon: meta.icon,
                            color: meta.colorOf(context),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ecoTypeLabel(activity['type'] as String?),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${meta.label} · ${ecoFormatDate(activity['date'] as String?)}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: eco.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '+${ecoFormatKg(activity['co2_kg'] as num?)} kg',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: eco.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String? key, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ListenableBuilder(
        listenable: _history,
        builder: (context, _) => EcoChip(
          label: label,
          selected: _history.category == key,
          onTap: () => _history.setCategory(key),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.note,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final String unit;
  final String note;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final theme = Theme.of(context);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              GlowText(value, size: 22, color: accent),
              const SizedBox(width: 4),
              Text(
                unit,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: eco.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: theme.textTheme.labelSmall?.copyWith(
              color: eco.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SdgStrip extends StatelessWidget {
  const _SdgStrip({required this.summary});

  final Map<String, dynamic>? summary;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final theme = Theme.of(context);
    final byCategory =
        (summary?['by_category'] as Map<String, dynamic>?) ?? const {};
    final total = (summary?['total_co2_kg'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: eco.primary.withValues(alpha: context.isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: eco.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public, size: 16, color: eco.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'UN SDG ALIGNMENT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'by footprint share',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: eco.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < ecoCategories.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _SdgCard(
                    meta: ecoCategories[i],
                    entry:
                        byCategory[ecoCategories[i].key] as Map<String, dynamic>?,
                    share: total > 0
                        ? (((byCategory[ecoCategories[i].key]
                                        as Map<String, dynamic>?)?['co2_kg']
                                    as num?)?.toDouble() ??
                                0) /
                              total
                        : 0,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            total > 0
                ? 'Your logged CO₂ is split across the goals above — the bigger the bar, the more room to improve.'
                : 'Log activities to see how your footprint maps to the UN Sustainable Development Goals.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: eco.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SdgCard extends StatelessWidget {
  const _SdgCard({required this.meta, required this.entry, required this.share});

  final EcoCategoryMeta meta;
  final Map<String, dynamic>? entry;
  final double share;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final theme = Theme.of(context);
    final kg = (entry?['co2_kg'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: eco.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SDG ${meta.sdg}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
              ),
              Text(
                '${(share * 100).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: eco.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            kg > 0 ? '${ecoFormatKg(kg)} kg' : meta.sdgTitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: eco.textSecondary,
              fontSize: 9.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          EcoProgressBar(value: share, color: meta.colorOf(context), height: 4),
        ],
      ),
    );
  }
}

class _ChallengesCard extends StatelessWidget {
  const _ChallengesCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final theme = Theme.of(context);
    return Consumer<ChallengesProvider>(
      builder: (context, challenges, _) {
        final total = challenges.challenges.length;
        final done = challenges.completedCount;
        final fraction = total == 0 ? 0.0 : done / total;
        return EcoCard(
          onTap: onTap,
          child: Row(
            children: [
              TintedIcon(icon: Icons.flag, color: eco.categoryWater),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Challenges',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 18, color: eco.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$done of $total complete · ${challenges.points} pts',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: eco.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    EcoProgressBar(
                      value: fraction,
                      color: eco.categoryWater,
                      height: 5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final theme = Theme.of(context);
    return Consumer<AchievementsProvider>(
      builder: (context, achievements, _) {
        final total = achievements.total;
        final unlocked = achievements.unlocked;
        final fraction = total == 0 ? 0.0 : unlocked / total;
        return EcoCard(
          onTap: onTap,
          child: Row(
            children: [
              TintedIcon(icon: Icons.emoji_events, color: eco.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Achievements',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 18, color: eco.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$unlocked of $total unlocked · ${achievements.currentStreak}d streak',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: eco.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    EcoProgressBar(value: fraction, color: eco.warning, height: 5),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.message, required this.onLog});

  final String message;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final theme = Theme.of(context);
    return EcoCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: eco.textSecondary),
          ),
          const SizedBox(height: 6),
          TextButton(onPressed: onLog, child: const Text('Log an activity now')),
        ],
      ),
    );
  }
}

class _NotificationsBanner extends StatelessWidget {
  const _NotificationsBanner();

  Color _accent(BuildContext context, String? severity) {
    final eco = context.eco;
    switch (severity) {
      case 'warning':
        return eco.warning;
      case 'success':
        return eco.primary;
      case 'info':
      default:
        return eco.secondary;
    }
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'challenge':
        return Icons.emoji_events_outlined;
      case 'insight':
        return Icons.trending_down;
      case 'onboarding':
        return Icons.waving_hand_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final provider = context.watch<NotificationsProvider>();
    final items = provider.items.take(3).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final n in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: EcoCard(
              padding: const EdgeInsets.all(14),
              onTap: n['read'] == true
                  ? null
                  : () => provider.markRead(n['id'] as int),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TintedIcon(
                    icon: _icon(n['type'] as String?),
                    color: _accent(context, n['severity'] as String?),
                    size: 38,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (n['title'] as String?) ?? '',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (n['body'] as String?) ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: eco.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => provider.dismiss(n['id'] as int),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              final provider = context.read<NotificationsProvider>();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: provider,
                    child: const NotificationsScreen(),
                  ),
                ),
              );
            },
            child: Text(
              'View all (${provider.items.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                color: eco.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final theme = Theme.of(context);
    final offline = context.watch<OfflineProvider>();
    if (offline.pending == 0) return const SizedBox.shrink();
    final word = offline.pending == 1 ? 'activity' : 'activities';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EcoCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            TintedIcon(
              icon: Icons.cloud_off_outlined,
              color: eco.warning,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${offline.pending} $word saved offline.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            FilledButton.tonal(
              onPressed: offline.syncing
                  ? null
                  : () async {
                      final synced = await offline.sync();
                      final word = synced == 1 ? 'entry' : 'entries';
                      if (!context.mounted) return;
                      await context.read<DashboardProvider>().load();
                      if (context.mounted) {
                        ecoSnack(context, 'Synced $synced offline $word.');
                      }
                    },
              child: offline.syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sync now'),
            ),
          ],
        ),
      ),
    );
  }
}
