import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/eco_meta.dart';
import '../widgets/eco_widgets.dart';
import 'calendar_screen.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final theme = Theme.of(context);
    final summary = dashboard.summary;
    final score = dashboard.score;

    if (dashboard.loading && summary == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (dashboard.error != null && summary == null) {
      return _ErrorState(
        message: dashboard.error!,
        onRetry: dashboard.load,
      );
    }

    final total = (summary?['total_co2_kg'] as num?)?.toDouble() ?? 0;
    final byCategory =
        (summary?['by_category'] as Map<String, dynamic>?) ?? const {};
    final daily = ((summary?['daily'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    return RefreshIndicator(
      onRefresh: dashboard.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sustainability Analytics',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Carbon footprint metrics & trend breakdown',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: EcoColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CalendarScreen(),
                  ),
                ),
                icon: const Icon(Icons.calendar_month, size: 16),
                label: const Text('Calendar'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: PillSegmented<String>(
              options: const ['week', 'month'],
              value: dashboard.period,
              onChanged: (p) => dashboard.setPeriod(p),
              labelOf: (p) => p == 'week' ? '7 Days' : '30 Days',
            ),
          ),
          const SizedBox(height: 18),

          // Hero
          GradientHero(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'LOGGED CARBON FOOTPRINT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        score?['grade'] as String? ?? 'No data',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      ecoFormatKg(total),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'kg CO₂',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  score?['active_days'] == null
                      ? 'Log activities to build your trend.'
                      : 'Across ${score!['active_days']} active ${score['active_days'] == 1 ? 'day' : 'days'} in the last ${summary?['days']} days.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 14),
                Divider(color: Colors.white.withValues(alpha: 0.3), height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Equivalence(
                        icon: Icons.park_outlined,
                        text: total > 0
                            ? '${(total / ecoKgPerTreeMonth).toStringAsFixed(1)} tree-months to absorb'
                            : '— tree-months',
                      ),
                    ),
                    Expanded(
                      child: _Equivalence(
                        icon: Icons.directions_car_outlined,
                        text: total > 0
                            ? '≈ ${(total / ecoKgPerCarKm).round()} km petrol car'
                            : '≈ 0 km petrol car',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Trend chart
          EcoCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dashboard.period == 'week'
                      ? '7-DAY CARBON TRAJECTORY'
                      : '30-DAY CARBON TRAJECTORY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Daily CO₂ logged (kg)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.muted,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 140,
                  child: _DailyBars(daily: daily),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Pillar breakdown
          EcoCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FOOTPRINT BY PILLAR',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Relative contribution to your carbon load',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.muted,
                  ),
                ),
                const SizedBox(height: 16),
                ...ecoCategories.map((meta) {
                  final entry =
                      byCategory[meta.key] as Map<String, dynamic>?;
                  final kg = (entry?['co2_kg'] as num?)?.toDouble() ?? 0;
                  final share = total > 0 ? kg / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(meta.icon, size: 15, color: meta.color),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                meta.label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${ecoFormatKg(kg)} kg (${(share * 100).round()}%)',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        EcoProgressBar(value: share, color: meta.color),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SdgTargets(byCategory: byCategory, total: total),
        ],
      ),
    );
  }
}

class _Equivalence extends StatelessWidget {
  const _Equivalence({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.daily});

  final List<Map<String, dynamic>> daily;

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) {
      return Center(
        child: Text(
          'No data in this period yet.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.muted),
        ),
      );
    }
    final values = daily
        .map((d) => (d['co2_kg'] as num?)?.toDouble() ?? 0)
        .toList();
    final maxVal = values.fold<double>(1, (m, v) => v > m ? v : m);
    final showEvery = daily.length > 10 ? 5 : 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < daily.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message:
                        '${ecoFormatDate(daily[i]['date'] as String?)}: ${ecoFormatKg(values[i])} kg',
                    child: Container(
                      height: (values[i] / maxVal) * 96 + 3,
                      decoration: BoxDecoration(
                        color: values[i] > 0
                            ? EcoColors.brand
                            : context.hairline,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    showEvery == 1 || i % showEvery == 0
                        ? _shortLabel(daily[i]['date'] as String?, daily.length)
                        : '',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.muted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _shortLabel(String? iso, int length) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '';
    if (length > 10) return '${d.day}';
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return names[d.weekday - 1];
  }
}

class _SdgTargets extends StatefulWidget {
  const _SdgTargets({required this.byCategory, required this.total});

  final Map<String, dynamic> byCategory;
  final double total;

  @override
  State<_SdgTargets> createState() => _SdgTargetsState();
}

class _SdgTargetsState extends State<_SdgTargets> {
  String? _expanded;

  static const _descriptions = {
    6: 'Targets universal clean water access and protection of freshwater ecosystems. Your tap-water and rainwater logs count directly here.',
    7: 'Promotes universal clean electricity and renewable grid adoption. Your grid and solar energy logs align here.',
    12: 'Focuses on waste reduction, reuse and circular life-cycles. Your recycling, compost and reuse logs advance this target.',
    13: 'Urgent global action to combat climate change. Your transport logs — walking, cycling and public transit — cut greenhouse gases.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EcoCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public, size: 16, color: EcoColors.brand),
              const SizedBox(width: 6),
              Text(
                'UN SDG IMPACT AREAS',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'How your logged footprint maps to the UN goals',
            style: theme.textTheme.labelSmall?.copyWith(color: context.muted),
          ),
          const SizedBox(height: 14),
          ...ecoCategories.map((meta) {
            final entry = widget.byCategory[meta.key] as Map<String, dynamic>?;
            final kg = (entry?['co2_kg'] as num?)?.toDouble() ?? 0;
            final share = widget.total > 0 ? kg / widget.total : 0.0;
            final expanded = _expanded == meta.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(
                  () => _expanded = expanded ? null : meta.key,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: expanded
                        ? EcoColors.brand.withValues(alpha: 0.08)
                        : (context.isDark
                              ? EcoColors.darkBg
                              : const Color(0xFFF6FBF8)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: expanded
                          ? EcoColors.brand
                          : Theme.of(context).colorScheme.surface,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'SDG ${meta.sdg}: ${meta.sdgTitle}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${(share * 100).round()}%',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: EcoColors.brand,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kg > 0
                            ? '${ecoFormatKg(kg)} kg CO₂ logged here'
                            : 'Nothing logged here yet',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: context.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      EcoProgressBar(
                        value: share,
                        color: meta.color,
                        height: 6,
                      ),
                      if (expanded) ...[
                        const SizedBox(height: 10),
                        Text(
                          _descriptions[meta.sdg] ?? '',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: context.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: EcoColors.rose),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
