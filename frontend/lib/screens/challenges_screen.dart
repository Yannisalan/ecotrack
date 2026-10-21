import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/challenges_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/eco_meta.dart';
import '../widgets/eco_widgets.dart';

IconData _challengeIcon(Map<String, dynamic> c) {
  switch (c['code'] as String?) {
    case 'daily_energy':
    case 'daily_energy_three':
      return Icons.bolt;
    case 'weekly_transport':
      return Icons.directions_car;
    case 'weekly_categories':
      return Icons.category_outlined;
    case 'weekly_days':
      return Icons.date_range;
    default:
      return c['period'] == 'weekly' ? Icons.date_range : Icons.today;
  }
}

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallengesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Challenges')),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            _PointsHero(provider: provider),
            const SizedBox(height: 22),
            if (provider.loading && provider.challenges.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null && provider.challenges.isEmpty)
              _ErrorState(message: provider.error!, onRetry: provider.load)
            else if (provider.challenges.isEmpty)
              const _EmptyState()
            else ...[
              _ChallengeSection(
                title: 'Daily',
                subtitle: 'Resets every day at midnight',
                items: provider.byPeriod('daily'),
              ),
              const SizedBox(height: 22),
              _ChallengeSection(
                title: 'Weekly',
                subtitle: 'Resets each Monday (ISO week)',
                items: provider.byPeriod('weekly'),
              ),
            ],
            if (provider.history.isNotEmpty) ...[
              const SizedBox(height: 22),
              SectionLabel(
                label: 'Recent completions',
                icon: Icons.history,
                trailing: Text(
                  '${provider.completedTotal} all time',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.muted,
                  ),
                ),
              ),
              ...provider.history.take(5).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _HistoryCard(item: item),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PointsHero extends StatelessWidget {
  const _PointsHero({required this.provider});

  final ChallengesProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GradientHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ECO POINTS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white70,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${provider.points}',
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${provider.completedCount} of ${provider.challenges.length} challenges completed in this period',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ChallengeSection extends StatelessWidget {
  const _ChallengeSection({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          label: title,
          icon: title == 'Weekly' ? Icons.date_range : Icons.today,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.muted),
        ),
        const SizedBox(height: 10),
        ...items.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChallengeCard(challenge: c),
          ),
        ),
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge});

  final Map<String, dynamic> challenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = challenge['completed'] == true;
    final target = (challenge['target'] as num?)?.toDouble() ?? 1;
    final progress = (challenge['progress'] as num?)?.toDouble() ?? 0;
    final fraction = target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;
    final reward = (challenge['reward_points'] as num?)?.toInt() ?? 0;

    return EcoCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintedIcon(
            icon: completed ? Icons.check_circle : _challengeIcon(challenge),
            color: completed ? EcoColors.brand : EcoColors.energy,
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
                        challenge['title'] as String? ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '+$reward pts',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: EcoColors.amber,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  challenge['description'] as String? ?? '',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: EcoProgressBar(
                        value: fraction,
                        color: completed ? EcoColors.brand : EcoColors.energy,
                        height: 5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      completed
                          ? 'Done'
                          : '${progress.toStringAsFixed(0)}/${target.toStringAsFixed(0)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: completed ? EcoColors.brand : context.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reward = (item['reward_points'] as num?)?.toInt() ?? 0;
    final completed = item['completed_at'] as String?;
    return EcoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 20, color: EcoColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] as String? ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${item['period_key'] ?? ''} · ${ecoFormatDate(completed)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+$reward',
            style: theme.textTheme.labelMedium?.copyWith(
              color: EcoColors.amber,
              fontWeight: FontWeight.w800,
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
          const Icon(Icons.cloud_off, size: 34, color: EcoColors.rose),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.muted),
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.flag_outlined, size: 34, color: EcoColors.brand),
          const SizedBox(height: 8),
          Text(
            'No challenges available',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
