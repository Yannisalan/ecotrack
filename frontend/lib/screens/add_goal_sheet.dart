import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/goals_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/eco_meta.dart';
import '../widgets/eco_widgets.dart';

/// Reference "New target" modal, wired to POST /api/goals.
Future<bool?> showAddGoalSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _AddGoalSheet(),
  );
}

class _GoalMetric {
  const _GoalMetric(this.value, this.label, this.unit);
  final String value;
  final String label;
  final String? unit;
}

const _metrics = <_GoalMetric>[
  _GoalMetric('co2', 'Reduce CO₂ (kg)', 'kg'),
  _GoalMetric('transport', 'Mobility distance', 'km'),
  _GoalMetric('electricity', 'Energy used', 'kWh'),
  _GoalMetric('water', 'Water used', 'litres'),
  _GoalMetric('waste', 'Waste handled', 'kg'),
  _GoalMetric('activities', 'Activities logged', null),
];

class _AddGoalSheet extends StatefulWidget {
  const _AddGoalSheet();

  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  final _title = TextEditingController();
  final _target = TextEditingController();
  _GoalMetric _metric = _metrics.first;
  DateTime? _endDate;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final target = double.tryParse(_target.text.trim());
    if (title.isEmpty) {
      setState(() => _error = 'Give your goal a name.');
      return;
    }
    if (target == null || target <= 0) {
      setState(() => _error = 'Target must be a positive number.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await context.read<GoalsProvider>().create(
      title: title,
      metric: _metric.value,
      targetValue: target,
      unit: _metric.unit,
      endDate: _endDate == null
          ? null
          : '${_endDate!.year.toString().padLeft(4, '0')}-'
                '${_endDate!.month.toString().padLeft(2, '0')}-'
                '${_endDate!.day.toString().padLeft(2, '0')}',
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _error = error;
        _saving = false;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.hairline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'New Goal',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const SectionLabel(label: 'What do you want to track?'),
              DropdownButtonFormField<_GoalMetric>(
                initialValue: _metric,
                decoration: const InputDecoration(isDense: true),
                items: _metrics
                    .map(
                      (m) => DropdownMenuItem(value: m, child: Text(m.label)),
                    )
                    .toList(),
                onChanged: (m) => setState(() => _metric = m ?? _metrics.first),
              ),
              const SizedBox(height: 14),
              const SectionLabel(label: 'Goal name'),
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. Cycle 40 km this month',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              SectionLabel(
                label: _metric.unit == null
                    ? 'Target (count)'
                    : 'Target (${_metric.unit})',
              ),
              TextField(
                controller: _target,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: '100',
                  isDense: true,
                  suffixText: _metric.unit,
                ),
              ),
              const SizedBox(height: 14),
              const SectionLabel(label: 'Deadline (optional)'),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        _endDate ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (picked != null && mounted) {
                    setState(() => _endDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.hairline),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 18,
                        color: context.eco.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _endDate == null
                              ? 'No deadline'
                              : ecoFormatDate(_endDate!.toIso8601String()),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (_endDate != null)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _endDate = null),
                          icon: const Icon(Icons.close, size: 16),
                        ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.eco.danger,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.eco.onPrimary,
                          ),
                        )
                      : const Icon(Icons.flag_outlined, size: 18),
                  label: Text(_saving ? 'Saving…' : 'Create Goal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
