import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/activity_api.dart';
import '../services/api_service.dart';
import '../services/error_messages.dart';
import '../services/offline.dart';
import '../theme/app_theme.dart';
import '../widgets/eco_meta.dart';
import '../widgets/eco_widgets.dart';

/// Opens the reference-style bottom sheet for logging one activity.
/// Returns true when something was saved online, or 'offline' when it was
/// queued for later sync.
Future<Object?> showLogActivitySheet(
  BuildContext context, {
  String? category,
}) {
  return showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => LogActivitySheet(initialCategory: category),
  );
}

class LogActivitySheet extends StatefulWidget {
  const LogActivitySheet({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  State<LogActivitySheet> createState() => _LogActivitySheetState();
}

class _LogActivitySheetState extends State<LogActivitySheet> {
  Map<String, Map<String, dynamic>> _options = {};
  String? _category;
  String? _type;
  double _quantity = 1;
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await context.read<ApiService>().getActivityOptions();
      final categories = ecoCategories
          .where((c) => options.containsKey(c.key))
          .toList();
      final first = widget.initialCategory != null &&
              options.containsKey(widget.initialCategory)
          ? widget.initialCategory!
          : (categories.isNotEmpty ? categories.first.key : null);
      if (!mounted) return;
      setState(() {
        _options = options;
        _category = first;
        _type = first == null
            ? null
            : (_options[first]!['types'] as List).first as String;
        _quantity = _defaultQuantity(first);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  double _defaultQuantity(String? category) {
    if (category == 'transport') return 10;
    if (category == 'electricity') return 5;
    if (category == 'water') return 50;
    if (category == 'waste') return 3;
    return 1;
  }

  ({double max, int divisions}) _range(String? category) {
    switch (category) {
      case 'transport':
        return (max: 300, divisions: 60);
      case 'electricity':
        return (max: 60, divisions: 60);
      case 'water':
        return (max: 500, divisions: 100);
      case 'waste':
        return (max: 50, divisions: 50);
      default:
        return (max: 100, divisions: 100);
    }
  }

  String? get _unit => _options[_category]?['unit'] as String?;

  List<String> get _types =>
      (_options[_category]?['types'] as List?)?.cast<String>() ?? const [];

  Future<void> _save() async {
    final settings = context.read<SettingsProvider>();
    final unit = _unit;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await createActivityOrQueue(
        context.read<ApiService>(),
        category: _category!,
        type: _type!,
        quantity: settings.toBackend(_quantity, unit),
        date:
            '${_date.year.toString().padLeft(4, '0')}-'
            '${_date.month.toString().padLeft(2, '0')}-'
            '${_date.day.toString().padLeft(2, '0')}',
      );
      if (!mounted) return;
      Navigator.of(context).pop(created == null ? 'offline' : true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _saving = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final unitShort = settings.displayUnitShort(_unit);
    final range = _range(_category);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          maxWidth: 480,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.hairline,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 10, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Log Activity',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel(
                            label: 'Category',
                            icon: Icons.category_outlined,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ecoCategories
                                .where(
                                  (c) => _options.containsKey(c.key),
                                )
                                .map(
                                  (c) => EcoChip(
                                    label: c.label,
                                    icon: c.icon,
                                    color: c.colorOf(context),
                                    selected: _category == c.key,
                                    onTap: () => setState(() {
                                      _category = c.key;
                                      _type = _types.isEmpty
                                          ? null
                                          : _types.first;
                                      _quantity = _defaultQuantity(c.key);
                                    }),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 18),
                          const SectionLabel(
                            label: 'Type',
                            icon: Icons.tune,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _types
                                .map(
                                  (t) => EcoChip(
                                    label: ecoTypeLabel(t),
                                    selected: _type == t,
                                    onTap: () => setState(() => _type = t),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 18),
                          SectionLabel(
                            label: 'Amount ($unitShort)',
                            icon: Icons.speed,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: _quantity.clamp(0, range.max),
                                  min: 0,
                                  max: range.max,
                                  divisions: range.divisions,
                                  label: '${ecoFormatQty(_quantity)} $unitShort',
                                  onChanged: (v) =>
                                      setState(() => _quantity = v),
                                ),
                              ),
                              SizedBox(
                                width: 86,
                                child: TextFormField(
                                  key: ValueKey('${_category}_$unitShort'),
                                  initialValue: ecoFormatQty(_quantity),
                                  textAlign: TextAlign.center,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    suffixText: unitShort,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 12,
                                        ),
                                  ),
                                  onChanged: (raw) {
                                    final parsed = double.tryParse(raw);
                                    if (parsed != null &&
                                        parsed >= 0 &&
                                        parsed <= range.max) {
                                      setState(() => _quantity = parsed);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _pickDate,
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
                                      'Date: ${ecoFormatDate(_date.toIso8601String())}',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                    color: context.muted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'CO₂ is calculated by the server from the official '
                            'factor table when you save.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.muted,
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: context.eco.danger,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: (_saving || _type == null)
                                  ? null
                                  : _save,
                              icon: _saving
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: context.eco.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.check, size: 18),
                              label: Text(
                                _saving ? 'Saving…' : 'Save Activity',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
