import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/activity_api.dart';
import '../services/api_service.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/eco_meta.dart';
import '../widgets/eco_widgets.dart';
import 'log_activity_screen.dart';

/// Read-only detail of one logged activity with edit + delete actions.
/// Returns true when the activity was changed or removed.
Future<bool?> showActivityDetailSheet(
  BuildContext context, {
  required Map<String, dynamic> activity,
  required Future<void> Function() onChanged,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ActivityDetailSheet(
      activity: activity,
      onChanged: onChanged,
    ),
  );
}

class _ActivityDetailSheet extends StatefulWidget {
  const _ActivityDetailSheet({required this.activity, required this.onChanged});

  final Map<String, dynamic> activity;
  final Future<void> Function() onChanged;

  @override
  State<_ActivityDetailSheet> createState() => _ActivityDetailSheetState();
}

class _ActivityDetailSheetState extends State<_ActivityDetailSheet> {
  bool _busy = false;

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LogActivityScreen(existing: widget.activity),
      ),
    );
    if (changed == true) {
      await widget.onChanged();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete activity?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: EcoColors.rose),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<ApiService>().deleteActivity(
        (widget.activity['id'] as num).toInt(),
      );
      await widget.onChanged();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ecoSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final a = widget.activity;
    final meta = ecoCategory(a['category'] as String?);
    final unit = a['unit'] as String?;
    final quantity = settings.toDisplay(
      (a['quantity'] as num?)?.toDouble() ?? 0,
      unit,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
            Row(
              children: [
                TintedIcon(icon: meta.icon, color: meta.color, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ecoTypeLabel(a['type'] as String?),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${meta.label} · ${ecoFormatDate(a['date'] as String?)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _Fact(
                    label: 'Amount',
                    value:
                        '${ecoFormatQty(quantity)} ${settings.displayUnitShort(unit)}',
                  ),
                ),
                Expanded(
                  child: _Fact(
                    label: 'CO₂ logged',
                    value: '${ecoFormatKg(a['co2_kg'] as num?)} kg',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _edit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: EcoColors.rose,
                    ),
                    onPressed: _busy ? null : _delete,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.8,
            color: context.muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
