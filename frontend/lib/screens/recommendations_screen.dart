import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/insights_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/eco_meta.dart';
import '../widgets/eco_widgets.dart';
import 'app_shell.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key, required this.onLogAction});

  final LogActionHandler onLogAction;

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final theme = Theme.of(context);
    final recs = dashboard.recommendations;

    final categories = <String>{
      for (final r in recs)
        if ((r['category'] as String?) != null &&
            r['category'] != 'general')
          r['category'] as String,
    }.toList();

    final filtered = _filter == 'all'
        ? recs
        : recs.where((r) => r['category'] == _filter).toList();

    if (dashboard.loading && recs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (dashboard.error != null && recs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 40, color: EcoColors.rose),
              const SizedBox(height: 10),
              Text(dashboard.error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: dashboard.load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final hero = recs.isNotEmpty ? recs.first : null;

    return RefreshIndicator(
      onRefresh: dashboard.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
        children: [
          Text(
            'Eco Recommendations',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Insights and actions based on what you log',
            style: theme.textTheme.bodySmall?.copyWith(
              color: EcoColors.brand,
            ),
          ),
          const SizedBox(height: 16),

          const _InsightsSection(),
          const SizedBox(height: 20),

          if (hero != null) _HeroRecommendation(rec: hero, onLog: widget.onLogAction),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: SectionLabel(
                  label: 'Curated Action Guide',
                  icon: Icons.lightbulb_outline,
                ),
              ),
              Text(
                '${filtered.length} available',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.muted,
                ),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                EcoChip(
                  label: 'All Actions',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                ...categories.map((key) {
                  final meta = ecoCategory(key);
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: EcoChip(
                      label: meta.label,
                      icon: meta.icon,
                      color: meta.color,
                      selected: _filter == key,
                      onTap: () => setState(() => _filter = key),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            EcoCard(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No recommendations for this filter.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.muted,
                  ),
                ),
              ),
            )
          else
            ...filtered.map(
              (rec) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecommendationCard(
                  rec: rec,
                  onLog: widget.onLogAction,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InsightsSection extends StatelessWidget {
  const _InsightsSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InsightsProvider>();
    final data = provider.data;
    final theme = Theme.of(context);

    return EcoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, size: 15, color: EcoColors.brand),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'INSIGHTS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: context.muted,
                  ),
                ),
              ),
              PillSegmented<String>(
                options: const ['week', 'month'],
                value: provider.period,
                onChanged: provider.setPeriod,
                labelOf: (v) => v == 'week' ? 'Week' : 'Month',
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (provider.loading && data == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.error != null && data == null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    provider.error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.muted,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: provider.load,
                  child: const Text('Retry'),
                ),
              ],
            )
          else if (data != null)
            _InsightsBody(data: data)
          else
            Text(
              'Log an activity to unlock your personalised insights.',
              style: theme.textTheme.bodySmall?.copyWith(color: context.muted),
            ),
        ],
      ),
    );
  }
}

class _InsightsBody extends StatelessWidget {
  const _InsightsBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = data['has_data'] == true;
    if (!hasData) {
      return Text(
        (data['summary'] as String?) ??
            'Log an activity to unlock your personalised insights.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: context.muted,
          height: 1.4,
        ),
      );
    }

    final score = data['eco_score'] as Map<String, dynamic>?;
    final total = (data['total_co2_kg'] as num?)?.toDouble() ?? 0;
    final avg = (score?['avg_daily_co2_kg'] as num?)?.toDouble();
    final change = (data['change_pct'] as num?)?.toDouble();
    final trend = data['trend'] as String?;
    final top = data['top_category'] as Map<String, dynamic>?;
    final projection = data['projection'] as Map<String, dynamic>?;
    final highlights = (data['highlights'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final watchouts = (data['watchouts'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    final trendColor = switch (trend) {
      'improving' => EcoColors.brand,
      'worsening' => EcoColors.rose,
      _ => context.muted,
    };
    final trendLabel = change == null
        ? (trend == 'new' ? 'New' : '—')
        : '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}%';
    final topMeta = top == null ? null : ecoCategory(top['category'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'TOTAL',
                value: '${ecoFormatKg(total)} kg',
              ),
            ),
            Expanded(
              child: _Metric(
                label: 'AVG / DAY',
                value: avg == null ? '—' : '${ecoFormatKg(avg)} kg',
              ),
            ),
            Expanded(
              child: _Metric(
                label: 'VS PREVIOUS',
                value: trendLabel,
                color: trendColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (topMeta != null)
          Row(
            children: [
              Icon(topMeta.icon, size: 15, color: topMeta.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Biggest source: ${topMeta.label} · '
                  '${((top!['share'] as num?)?.toDouble() ?? 0) * 100 ~/ 1}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.muted,
                  ),
                ),
              ),
            ],
          ),
        if (projection != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Projected at this pace: '
              '${ecoFormatKg(projection['monthly_co2_kg'] as num?)} kg/month · '
              '${projection['annual_tonnes']} t/year',
              style: theme.textTheme.labelSmall?.copyWith(
                color: context.muted,
              ),
            ),
          ),
        if (highlights.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...highlights.take(2).map(
            (h) => _InsightRow(
              icon: Icons.check_circle_outline,
              color: EcoColors.brand,
              title: h['title'] as String? ?? '',
              body: h['body'] as String? ?? '',
            ),
          ),
        ],
        if (watchouts.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...watchouts.take(2).map(
            (w) => _InsightRow(
              icon: Icons.error_outline,
              color: EcoColors.energy,
              title: w['title'] as String? ?? '',
              body: w['body'] as String? ?? '',
            ),
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: context.muted,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  body,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroRecommendation extends StatelessWidget {
  const _HeroRecommendation({required this.rec, required this.onLog});

  final Map<String, dynamic> rec;
  final LogActionHandler onLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = rec['category'] as String?;
    final saving =
        (rec['estimated_saving_co2_kg'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(EcoTheme.cardRadius),
        border: Border.all(color: EcoColors.brand.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.isDark
              ? [
                  EcoColors.darkSurface,
                  EcoColors.brand.withValues(alpha: 0.12),
                ]
              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: EcoColors.brand),
              const SizedBox(width: 6),
              Text(
                'TOP HIGH-IMPACT RECOMMENDATION',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: EcoColors.brandDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rec['title'] as String? ?? 'Recommendation',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rec['message'] as String? ?? '',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  saving > 0
                      ? '-${ecoFormatKg(saving)} kg CO₂ potential saving'
                      : 'Keep logging to unlock savings',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: EcoColors.brandDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (category != null && category != 'general')
                FilledButton.icon(
                  onPressed: () => onLog(category: category),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Log Action'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
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

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.rec, required this.onLog});

  final Map<String, dynamic> rec;
  final LogActionHandler onLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = rec['category'] as String?;
    final isGeneral = category == null || category == 'general';
    final meta = ecoCategory(category);
    final saving =
        (rec['estimated_saving_co2_kg'] as num?)?.toDouble() ?? 0;

    return EcoCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintedIcon(
            icon: isGeneral ? Icons.eco_outlined : meta.icon,
            color: isGeneral ? EcoColors.brand : meta.color,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec['title'] as String? ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isGeneral
                      ? 'General'
                      : '${meta.label} · SDG ${meta.sdg}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  rec['message'] as String? ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        saving > 0
                            ? '-${ecoFormatKg(saving)} kg CO₂'
                            : 'No estimate yet',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: EcoColors.brand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!isGeneral)
                      OutlinedButton.icon(
                        onPressed: () => onLog(category: category),
                        icon: const Icon(Icons.add, size: 15),
                        label: const Text('Log Action'),
                        style: OutlinedButton.styleFrom(
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
          ),
        ],
      ),
    );
  }
}
