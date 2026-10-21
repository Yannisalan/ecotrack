import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/settings_provider.dart';
import '../services/activity_api.dart';
import '../services/api_service.dart';
import '../services/reports_api.dart';
import '../services/stats_api.dart';
import '../theme/app_theme.dart';
import '../widgets/eco_meta.dart';
import '../widgets/eco_widgets.dart';
import 'tips_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _streak = 0;
  int _activityCount = 0;
  double _commuteKm = 18;
  String _diet = 'low_meat';
  String _energy = 'heat_pump';
  bool _exporting = false;
  bool _reporting = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    final api = context.read<ApiService>();
    try {
      final streak = await api.getStreak();
      if (mounted) {
        setState(
          () => _streak = (streak['current_streak'] as num?)?.toInt() ?? 0,
        );
      }
    } on ApiException {
      // Non-critical; leave at 0.
    }
    try {
      final data = await api.listActivities(limit: 1, offset: 0);
      if (mounted) {
        setState(() => _activityCount = (data['total'] as num?)?.toInt() ?? 0);
      }
    } on ApiException {
      // Non-critical; leave at 0.
    }
  }

  double get _annualBaselineKg =>
      _commuteKm * 250 * 0.16 +
      switch (_diet) { 'plant' => 1200.0, 'low_meat' => 1900.0, _ => 2800.0 } +
      switch (_energy) { 'solar' => 600.0, 'heat_pump' => 1400.0, _ => 2400.0 };

  Future<void> _export({required bool asJson}) async {
    setState(() => _exporting = true);
    try {
      final data = await context.read<ApiService>().listActivities(
        limit: 1000,
        offset: 0,
      );
      final activities = (data['activities'] as List)
          .cast<Map<String, dynamic>>();
      final text = asJson
          ? const JsonEncoder.withIndent('  ').convert(activities)
          : _toCsv(activities);
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ecoSnack(
        context,
        '${activities.length} activities copied to clipboard as ${asJson ? 'JSON' : 'CSV'}.',
      );
    } on ApiException catch (e) {
      if (mounted) ecoSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _fetchServerReport({required bool pdf}) async {
    setState(() => _reporting = true);
    final api = context.read<ApiService>();
    final period = context.read<DashboardProvider>().period;
    try {
      if (pdf) {
        final bytes = await api.getSummaryPdf(period);
        await Clipboard.setData(
          ClipboardData(text: base64Encode(bytes)),
        );
        if (!mounted) return;
        ecoSnack(
          context,
          'Summary PDF (${bytes.length} bytes) copied to clipboard as base64.',
        );
      } else {
        final csv = await api.getActivitiesCsv(period);
        await Clipboard.setData(ClipboardData(text: csv));
        if (!mounted) return;
        ecoSnack(context, 'Server CSV report ($period) copied to clipboard.');
      }
    } on ApiException catch (e) {
      if (mounted) ecoSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  String _toCsv(List<Map<String, dynamic>> activities) {
    final buffer = StringBuffer('date,category,type,quantity,unit,co2_kg\n');
    for (final a in activities) {
      buffer.writeln(
        '${a['date']},${a['category']},${a['type']},${a['quantity']},${a['unit']},${a['co2_kg']}',
      );
    }
    return buffer.toString();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently removes your account, activities and goals. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: EcoColors.rose),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final error = await context.read<AuthProvider>().deleteAccount();
    if (!mounted) return;
    if (error != null) {
      setState(() => _deleting = false);
      ecoSnack(context, error, error: true);
    }
  }

  Future<void> _showChangePassword() async {
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (!mounted || result == null) return;
    ecoSnack(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final score = context.watch<DashboardProvider>().score;
    final theme = Theme.of(context);
    final name = auth.userName.isNotEmpty ? auth.userName : 'User';
    final grade = score?['grade'] as String?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
      children: [
        // Identity
        EcoCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: EcoColors.brand.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: EcoColors.brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      auth.user?['email']?.toString() ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.muted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (grade != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: ecoGradeColor(
                                grade,
                              ).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              grade,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: ecoGradeColor(grade),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.local_fire_department,
                          size: 15,
                          color: EcoColors.amber,
                        ),
                        Text(
                          ' $_streak day streak · $_activityCount logged',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: context.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Baseline estimator
        EcoCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calculate_outlined,
                    size: 18,
                    color: EcoColors.brand,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Baseline Footprint Estimator',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Local estimate from your lifestyle inputs — not saved to your account.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.muted,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Daily commute',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${_commuteKm.round()} km/day',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _commuteKm,
                min: 0,
                max: 60,
                divisions: 60,
                label: '${_commuteKm.round()} km',
                onChanged: (v) => setState(() => _commuteKm = v),
              ),
              const SizedBox(height: 6),
              Text('Diet profile', style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              _choiceRow(
                [
                  ('plant', 'Plant-rich'),
                  ('low_meat', 'Flexitarian'),
                  ('standard', 'Omnivore'),
                ],
                _diet,
                (v) => setState(() => _diet = v),
              ),
              const SizedBox(height: 14),
              Text('Home energy', style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              _choiceRow(
                [
                  ('solar', 'Solar rooftop'),
                  ('heat_pump', 'Heat pump'),
                  ('gas', 'Gas / grid'),
                ],
                _energy,
                (v) => setState(() => _energy = v),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: EcoColors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESTIMATED BASELINE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: EcoColors.brandDark,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            '${(_annualBaselineKg / 1000).toStringAsFixed(2)} t CO₂ / year',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: EcoColors.brandDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'EU avg: 8.5 t',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Preferences
        EcoCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel(
                label: 'Preferences',
                icon: Icons.settings_outlined,
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Measurement units',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          settings.unitsLabel(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: context.muted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: PillSegmented<UnitSystem>(
                  options: const [UnitSystem.metric, UnitSystem.imperial],
                  value: settings.units,
                  onChanged: settings.setUnits,
                  labelOf: (u) => u == UnitSystem.metric
                      ? 'Metric (km, L)'
                      : 'Imperial (mi, gal)',
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Color theme',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Mint light or deep emerald',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: context.muted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: PillSegmented<ThemeMode>(
                  options: const [ThemeMode.light, ThemeMode.dark],
                  value: context.isDark ? ThemeMode.dark : ThemeMode.light,
                  onChanged: (mode) => settings.setThemeMode(mode),
                  labelOf: (m) => m == ThemeMode.light ? 'Light' : 'Dark',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Data export
        EcoCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel(
                label: 'Data Export',
                icon: Icons.download_outlined,
              ),
              Text(
                'Copies all your logged activities to the clipboard.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.muted,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exporting ? null : () => _export(asJson: false),
                      icon: const Icon(Icons.table_chart_outlined, size: 17),
                      label: const Text('Export CSV'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exporting ? null : () => _export(asJson: true),
                      icon: const Icon(Icons.data_object, size: 17),
                      label: const Text('Export JSON'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Server-generated reports
        EcoCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel(
                label: 'Server Reports',
                icon: Icons.description_outlined,
              ),
              Text(
                'Generated by the backend for the selected period '
                '(week/month). Copies to the clipboard.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.muted,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reporting
                          ? null
                          : () => _fetchServerReport(pdf: false),
                      icon: const Icon(Icons.grid_on_outlined, size: 17),
                      label: const Text('CSV report'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reporting
                          ? null
                          : () => _fetchServerReport(pdf: true),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                      label: const Text('PDF summary'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Tools
        EcoCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel(
                label: 'Tips',
                icon: Icons.lightbulb_outlined,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const TintedIcon(
                  icon: Icons.lightbulb_outlined,
                  color: EcoColors.water,
                ),
                title: const Text('Tips'),
                subtitle: const Text('Practical ways to reduce your footprint'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TipsScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Account
        EcoCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel(
                label: 'Account',
                icon: Icons.shield_outlined,
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.read<AuthProvider>().logout(),
                  icon: const Icon(Icons.logout, size: 17),
                  label: const Text('Log out'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showChangePassword,
                  icon: const Icon(Icons.lock_reset_outlined, size: 17),
                  label: const Text('Change password'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EcoColors.rose,
                    side: const BorderSide(color: EcoColors.rose),
                  ),
                  onPressed: _deleting ? null : _confirmDelete,
                  icon: _deleting
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: EcoColors.rose,
                          ),
                        )
                      : const Icon(Icons.delete_forever_outlined, size: 17),
                  label: const Text('Delete account'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _choiceRow(
    List<(String, String)> options,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(options[i].$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == options[i].$1
                      ? EcoColors.brand
                      : (context.isDark
                            ? EcoColors.darkBg
                            : const Color(0xFFE8F3ED)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  options[i].$2,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected == options[i].$1
                        ? Colors.white
                        : null,
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Prompts for the current and new password. Pops with a success message on
/// completion, or null if the user cancelled. All sessions are invalidated by
/// the backend after a change, so AuthProvider logs the user out on success.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await context.read<AuthProvider>().changePassword(
      _current.text,
      _next.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop('Password changed. Please log in again.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Change password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Current password',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your current password' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _next,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'New password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a new password';
                if (v.length < 8) return 'Use at least 8 characters';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Change'),
        ),
      ],
    );
  }
}
