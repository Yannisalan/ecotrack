import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/calendar_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/eco_widgets.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiService>();
    return ChangeNotifierProvider<CalendarProvider>(
      create: (_) => CalendarProvider(api)..load(),
      child: const _CalendarView(),
    );
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView();

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CalendarProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sustainability Calendar')),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: provider.loading ? null : provider.previousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    provider.monthLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: provider.loading ? null : provider.nextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (provider.error != null && provider.days.isEmpty)
              _ErrorState(message: provider.error!, onRetry: provider.load)
            else if (provider.loading && provider.days.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              EcoCard(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                child: Column(
                  children: [
                    Row(
                      children: _weekdayLabels
                          .map(
                            (w) => Expanded(
                              child: Text(
                                w,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: context.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    _MonthGrid(days: provider.days),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _Legend(),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.days});

  final List<Map<String, dynamic>> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final first = DateTime.parse(days.first['date'] as String);
    final leading = first.weekday - 1; // Monday = 0

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (final day in days) _DayCell(day: day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(
        Row(
          children: [
            for (var j = 0; j < 7; j++)
              Expanded(child: AspectRatio(aspectRatio: 1, child: cells[i + j])),
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

List<Color> _calendarLevelColors(BuildContext context) {
  final eco = context.eco;
  return [
    eco.surfaceElevated,
    const Color(0xFFA7F3D0),
    const Color(0xFF34D399),
    eco.warning,
    eco.danger,
  ];
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day});

  final Map<String, dynamic> day;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final levelColors = _calendarLevelColors(context);
    final date = DateTime.parse(day['date'] as String);
    final level = (day['level'] as num?)?.toInt() ?? 0;
    final today = _isToday(date);
    final color = levelColors[level.clamp(0, 4)];

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showDay(context, date, day),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: today
                ? Border.all(color: eco.borderStrong, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: today ? FontWeight.w800 : FontWeight.w600,
              color: level >= 3 ? eco.onPrimary : const Color(0xFF0E2018),
            ),
          ),
        ),
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  void _showDay(BuildContext context, DateTime date, Map<String, dynamic> day) {
    final entries = (day['entries'] as num?)?.toInt() ?? 0;
    final co2 = (day['co2_kg'] as num?)?.toDouble() ?? 0;
    final cats = (day['categories'] as List?)?.cast<String>() ?? const [];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: Theme.of(
                ctx,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text('$entries ${entries == 1 ? 'activity' : 'activities'} logged'),
            const SizedBox(height: 4),
            Text('${co2.toStringAsFixed(2)} kg CO₂'),
            if (cats.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: cats
                    .map((c) => Chip(label: Text(c)))
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  static const _labels = ['None', 'Low', 'Good', 'High', 'Very high'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelColors = _calendarLevelColors(context);
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (var i = 0; i < levelColors.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: levelColors[i],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _labels[i],
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.muted,
                ),
              ),
            ],
          ),
      ],
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
