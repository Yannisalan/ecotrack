import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/achievements_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/eco_widgets.dart';

const _categoryOrder = [
  'getting_started',
  'consistency',
  'challenges',
  'progress',
];

const _categoryMeta = {
  'getting_started': ('Getting Started', Icons.rocket_launch_outlined),
  'consistency': ('Consistency', Icons.local_fire_department_outlined),
  'challenges': ('Challenges', Icons.emoji_events_outlined),
  'progress': ('Progress', Icons.trending_up),
};

IconData _achievementIcon(String? code) => switch (code) {
  'leaf' => Icons.eco,
  'calendar' => Icons.calendar_month,
  'target' => Icons.track_changes,
  'flame' => Icons.local_fire_department,
  'check' => Icons.check_circle,
  'trophy' => Icons.emoji_events,
  'chart' => Icons.insights,
  'medal' => Icons.workspace_premium,
  'water_drop' => Icons.water_drop,
  'bus' => Icons.directions_bus,
  'flag' => Icons.flag,
  'military_tech' => Icons.military_tech,
  'workspace_premium' => Icons.workspace_premium,
  _ => Icons.emoji_events_outlined,
};

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AchievementsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            _StreakHero(provider: provider),
            const SizedBox(height: 22),
            if (provider.loading && provider.achievements.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null && provider.achievements.isEmpty)
              _ErrorState(message: provider.error!, onRetry: provider.load)
            else if (provider.achievements.isEmpty)
              _EmptyState()
            else
              ..._categoryOrder.map((cat) {
                final items = provider.byCategory(cat);
                if (items.isEmpty) return const SizedBox.shrink();
                final meta = _categoryMeta[cat]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(label: meta.$1, icon: meta.$2),
                    ...items.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AchievementCard(achievement: a),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.provider});

  final AchievementsProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onHero = context.eco.onPrimary;
    final fraction = provider.total == 0
        ? 0.0
        : provider.unlocked / provider.total;

    return GradientHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT STREAK',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: onHero.withValues(alpha: 0.7),
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${provider.currentStreak}',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: onHero,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            provider.currentStreak == 1 ? 'day' : 'days',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: onHero.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: onHero,
                    size: 34,
                  ),
                  Text(
                    'Longest ${provider.longestStreak}d',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: onHero.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${provider.unlocked} of ${provider.total} achievements unlocked',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onHero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 7,
              backgroundColor: onHero.withValues(alpha: 0.24),
              valueColor: AlwaysStoppedAnimation(onHero),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final Map<String, dynamic> achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eco = context.eco;
    final earned = achievement['earned'] == true;
    final target = (achievement['target'] as num?)?.toDouble() ?? 1;
    final progress = (achievement['progress'] as num?)?.toDouble() ?? 0;
    final fraction = target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

    return EcoCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: earned
                  ? eco.primary.withValues(alpha: 0.14)
                  : eco.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(
              earned
                  ? _achievementIcon(achievement['icon'] as String?)
                  : Icons.lock_outline,
              color: earned ? eco.primary : context.muted,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement['name'] as String? ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: earned ? null : context.muted,
                        ),
                      ),
                    ),
                    if (earned)
                      Icon(
                        Icons.check_circle,
                        size: 17,
                        color: eco.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  achievement['description'] as String? ?? '',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.muted,
                  ),
                ),
                if (!earned) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: EcoProgressBar(
                          value: fraction,
                          color: eco.primary,
                          height: 5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${progress.toStringAsFixed(0)}/${target.toStringAsFixed(0)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: context.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.cloud_off, size: 34, color: context.eco.danger),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.muted,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 34,
            color: context.eco.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'No achievements yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Log activities and set goals to start earning badges.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.muted),
          ),
        ],
      ),
    );
  }
}
