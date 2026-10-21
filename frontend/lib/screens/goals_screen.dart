import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/eco_meta.dart';
import '../widgets/eco_widgets.dart';
import 'add_goal_sheet.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  IconData _metricIcon(String? metric) => switch (metric) {
    'co2' => Icons.co2,
    'activities' => Icons.checklist_rtl,
    _ => ecoCategory(metric).icon,
  };

  Color _metricColor(String? metric) => switch (metric) {
    'co2' => EcoColors.brand,
    'activities' => EcoColors.sky,
    _ => ecoCategory(metric).color,
  };

  String _metricLabel(String? metric) => switch (metric) {
    'co2' => 'CO₂ reduction',
    'activities' => 'Activity count',
    _ => ecoCategory(metric).label,
  };

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalsProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: goals.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sustainability Targets',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your own reduction targets',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: EcoColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => showAddGoalSheet(context),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('New Target'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Active Targets',
                  value: '${goals.active.length}',
                  note: 'In progress',
                  accent: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Completed Goals',
                  value: '${goals.completed.length}',
                  note: 'Milestones unlocked',
                  accent: EcoColors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const SectionLabel(
            label: 'In-Flight Goals',
            icon: Icons.flag_outlined,
          ),
          if (goals.loading && goals.goals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (goals.error != null && goals.goals.isEmpty)
            EcoCard(
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
              child: Column(
                children: [
                  Text(
                    goals.error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: goals.load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (goals.active.isEmpty)
            EcoCard(
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
              child: Column(
                children: [
                  const Icon(
                    Icons.track_changes,
                    size: 34,
                    color: EcoColors.brand,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All current targets reached!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Set a new target to challenge your habits.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => showAddGoalSheet(context),
                    child: const Text('Add New Target'),
                  ),
                ],
              ),
            )
          else
            ...goals.active.map(
              (goal) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GoalCard(
                  goal: goal,
                  icon: _metricIcon(goal['metric'] as String?),
                  color: _metricColor(goal['metric'] as String?),
                  metricLabel: _metricLabel(goal['metric'] as String?),
                  settings: settings,
                  goals: goals,
                ),
              ),
            ),

          if (goals.completed.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            const SectionLabel(
              label: 'Achieved Milestones',
              icon: Icons.emoji_events_outlined,
            ),
            ...goals.completed.map(
              (goal) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: EcoCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: EcoColors.brand,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal['title'] as String? ?? '',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            Text(
                              'Target: ${ecoFormatQty((goal['target_value'] as num?)?.toDouble())} ${goal['unit'] ?? ''}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: context.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => goals.setStatus(
                          (goal['id'] as num).toInt(),
                          'active',
                        ),
                        child: const Text('Reopen'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.note,
    required this.accent,
  });

  final String label;
  final String value;
  final String note;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: context.muted),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.muted,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.icon,
    required this.color,
    required this.metricLabel,
    required this.settings,
    required this.goals,
  });

  final Map<String, dynamic> goal;
  final IconData icon;
  final Color color;
  final String metricLabel;
  final SettingsProvider settings;
  final GoalsProvider goals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = goal['unit'] as String?;
    final current = (goal['current_value'] as num?)?.toDouble() ?? 0;
    final target = (goal['target_value'] as num?)?.toDouble() ?? 0;
    final progress = target > 0 ? (current / target) : 0.0;
    final id = (goal['id'] as num).toInt();

    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TintedIcon(icon: icon, color: color, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal['title'] as String? ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$metricLabel · ${goal['end_date'] == null ? 'No deadline' : 'Due ${ecoFormatDate(goal['end_date'] as String?)}'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete goal',
                onPressed: () async {
                  final error = await goals.remove(id);
                  if (error != null && context.mounted) {
                    ecoSnack(context, error, error: true);
                  }
                },
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: context.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Progress (${(progress * 100).clamp(0, 100).round()}%)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${ecoFormatQty(settings.toDisplay(current, unit))} / ${ecoFormatQty(settings.toDisplay(target, unit))} ${settings.displayUnitShort(unit)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          EcoProgressBar(value: progress, color: color),
          const SizedBox(height: 12),
          Row(
            children: [
              _StepButton(
                label: '-1',
                onTap: () => goals.adjust(id, -settings.toBackend(1, unit)),
              ),
              const SizedBox(width: 6),
              _StepButton(
                label: '+1',
                onTap: () => goals.adjust(id, settings.toBackend(1, unit)),
              ),
              const SizedBox(width: 6),
              _StepButton(
                label: '+5',
                onTap: () => goals.adjust(id, settings.toBackend(5, unit)),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => goals.setStatus(id, 'completed'),
                icon: const Icon(Icons.check_circle_outline, size: 15),
                label: const Text('Complete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EcoColors.brand,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: context.isDark ? EcoColors.darkBg : const Color(0xFFE8F3ED),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
