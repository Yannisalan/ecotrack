import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/activity_api.dart';
import '../services/api_service.dart';

const _order = ['transport', 'electricity', 'water', 'waste'];
const _icons = <String, IconData>{
  'transport': Icons.directions_car_outlined,
  'electricity': Icons.bolt_outlined,
  'water': Icons.water_drop_outlined,
  'waste': Icons.delete_outline,
};
const _labels = <String, String>{
  'transport': 'Transport',
  'electricity': 'Electricity',
  'water': 'Water',
  'waste': 'Waste',
};

String _pretty(String s) {
  final t = s.replaceAll('_', ' ');
  return t[0].toUpperCase() + t.substring(1);
}

String _fmtNum(num n) =>
    n.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Log a new activity, or edit one when [existing] is given.
class LogActivityScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const LogActivityScreen({super.key, this.existing});

  @override
  State<LogActivityScreen> createState() => _LogActivityScreenState();
}

class _LogActivityScreenState extends State<LogActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();

  Map<String, Map<String, dynamic>>? _options;
  String? _category;
  String? _type;
  DateTime _date = DateTime.now();
  bool _loadingOptions = true;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  List<String> _typesFor(String category) =>
      (_options![category]!['types'] as List).cast<String>();

  List<String> get _categories =>
      _order.where((c) => _options!.containsKey(c)).toList();

  Future<void> _loadOptions() async {
    final api = context.read<ApiService>();
    try {
      final opts = await api.getActivityOptions();
      if (!mounted) return;
      setState(() {
        _options = opts;
        final ex = widget.existing;
        if (ex != null && opts.containsKey(ex['category'])) {
          _category = ex['category'] as String;
          final types = _typesFor(_category!);
          _type = types.contains(ex['type'])
              ? ex['type'] as String
              : types.first;
          _quantity.text = _fmtNum(ex['quantity'] as num);
          _date = DateTime.parse(ex['date'] as String);
        } else {
          _category = _categories.first;
          _type = _typesFor(_category!).first;
        }
        _loadingOptions = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loadingOptions = false;
      });
    }
  }

  void _selectCategory(String category) {
    setState(() {
      _category = category;
      _type = _typesFor(category).first;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _dateLabel() {
    final now = DateTime.now();
    final isToday =
        _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
    return isToday ? 'Today (${_iso(_date)})' : _iso(_date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final quantity = double.parse(_quantity.text.trim().replaceAll(',', '.'));
    final api = context.read<ApiService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> activity;
      if (_editing) {
        activity = await api.updateActivity(
          (widget.existing!['id'] as num).toInt(),
          category: _category!,
          type: _type!,
          quantity: quantity,
          date: _iso(_date),
        );
      } else {
        activity = await api.createActivity(
          category: _category!,
          type: _type!,
          quantity: quantity,
          date: _iso(_date),
        );
      }
      if (!mounted) return;
      final co2 = (activity['co2_kg'] as num).toDouble().toStringAsFixed(2);
      final verb = _editing ? 'Updated' : 'Logged';
      messenger.showSnackBar(
        SnackBar(content: Text('$verb. That is about $co2 kg CO2.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit activity' : 'Log activity')),
      body: _loadingOptions
          ? const Center(child: CircularProgressIndicator())
          : _options == null
          ? _errorView()
          : _form(context),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? 'Could not load the options.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() => _loadingOptions = true);
                _loadOptions();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unit = _options![_category]!['unit'] as String;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Category', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in _categories)
                      ChoiceChip(
                        avatar: Icon(_icons[c], size: 18),
                        label: Text(_labels[c] ?? c),
                        selected: c == _category,
                        onSelected: _saving ? null : (_) => _selectCategory(c),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  key: ValueKey(_category),
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final t in _typesFor(_category!))
                      DropdownMenuItem(value: t, child: Text(_pretty(t))),
                  ],
                  onChanged: _saving ? null : (v) => setState(() => _type = v),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantity,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onFieldSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    suffixText: unit,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final q = double.tryParse(
                      (v ?? '').trim().replaceAll(',', '.'),
                    );
                    if (q == null) return 'Enter a number';
                    if (q <= 0) return 'Must be greater than 0';
                    if (q > 1000000) return 'That number is too large';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_dateLabel()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: scheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_editing ? 'Save changes' : 'Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
