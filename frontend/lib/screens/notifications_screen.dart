import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notifications_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/eco_meta.dart';
import '../widgets/eco_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationsProvider>();
      if (provider.preferences == null) provider.loadPreferences();
    });
  }

  Color _accent(String? severity) {
    switch (severity) {
      case 'warning':
        return EcoColors.energy;
      case 'success':
        return EcoColors.brand;
      case 'info':
      default:
        return EcoColors.sky;
    }
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'challenge':
        return Icons.emoji_events_outlined;
      case 'achievement':
        return Icons.workspace_premium_outlined;
      case 'insight':
        return Icons.trending_down;
      case 'summary':
        return Icons.calendar_month_outlined;
      case 'onboarding':
        return Icons.waving_hand_outlined;
      case 'reminder':
        return Icons.alarm;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Future<void> _toggle(String key, bool value) async {
    final ok = await context.read<NotificationsProvider>().updatePreference(
      key,
      value,
    );
    if (!ok && mounted) {
      ecoSnack(
        context,
        context.read<NotificationsProvider>().preferencesError ??
            'Could not save preference',
        error: true,
      );
    }
  }

  Future<void> _setHour(int hour) async {
    final ok = await context.read<NotificationsProvider>().updatePreference(
      'reminder_hour',
      hour,
    );
    if (!ok && mounted) {
      ecoSnack(context, 'Could not save reminder time', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.unread > 0)
            TextButton(
              onPressed: provider.markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.load();
          await provider.loadPreferences();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            if (provider.loading && provider.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null && provider.items.isEmpty)
              _ErrorState(message: provider.error!, onRetry: provider.load)
            else if (provider.items.isEmpty)
              _EmptyState(theme: theme)
            else ...[
              SectionLabel(
                label: 'Inbox',
                icon: Icons.inbox_outlined,
                trailing: Text(
                  '${provider.unread} unread',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.muted,
                  ),
                ),
              ),
              ...provider.items.map(
                (n) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _NotificationCard(
                    notification: n,
                    accent: _accent(n['severity'] as String?),
                    icon: _icon(n['type'] as String?),
                    onRead: () => provider.markRead(n['id'] as int),
                    onDismiss: () => provider.dismiss(n['id'] as int),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SectionLabel(
              label: 'Reminders & alerts',
              icon: Icons.tune,
            ),
            _PreferencesCard(
              provider: provider,
              onToggle: _toggle,
              onHour: _setHour,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.accent,
    required this.icon,
    required this.onRead,
    required this.onDismiss,
  });

  final Map<String, dynamic> notification;
  final Color accent;
  final IconData icon;
  final VoidCallback onRead;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = notification['read'] != true;
    return EcoCard(
      onTap: unread ? onRead : null,
      padding: const EdgeInsets.all(14),
      color: unread
          ? accent.withValues(alpha: context.isDark ? 0.12 : 0.06)
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintedIcon(icon: icon, color: accent, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification['title'] as String? ?? '',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6, right: 4),
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  notification['body'] as String? ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ecoFormatDate(notification['created_at'] as String?),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 17),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({
    required this.provider,
    required this.onToggle,
    required this.onHour,
  });

  final NotificationsProvider provider;
  final Future<void> Function(String key, bool value) onToggle;
  final Future<void> Function(int hour) onHour;

  static const _labels = <String, (String, String)>{
    'daily_reminder': ('Daily check-in', 'A nudge if you have not logged today'),
    'streak_reminders': ('Streak reminders', 'Warn me when my streak is at risk'),
    'challenge_nudges': ('Challenge nudges', 'Progress and completion updates'),
    'trend_alerts': ('Trend alerts', 'When my footprint moves up or down'),
    'achievement_alerts': ('Badge alerts', 'When I unlock an achievement'),
    'weekly_summary': ('Weekly summary', 'A recap every Monday'),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = provider.preferences;

    return EcoCard(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
      child: provider.preferencesLoading && prefs == null
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          : prefs == null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      provider.preferencesError ?? 'Preferences unavailable',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.muted,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: provider.loadPreferences,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final entry in _labels.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.value.$1,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                entry.value.$2,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: context.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: prefs[entry.key] == true,
                          onChanged: (value) => onToggle(entry.key, value),
                        ),
                      ],
                    ),
                  ),
                Divider(color: context.hairline, height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reminder time',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DropdownButton<int>(
                      value: ((prefs['reminder_hour'] as num?)?.toInt() ?? 19)
                          .clamp(0, 23)
                          .toInt(),
                      underline: const SizedBox.shrink(),
                      items: [
                        for (var hour = 0; hour < 24; hour++)
                          DropdownMenuItem(
                            value: hour,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) onHour(value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_none,
            size: 34,
            color: EcoColors.brand,
          ),
          const SizedBox(height: 8),
          Text(
            'You are all caught up',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Reminders and progress alerts will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: context.muted),
          ),
        ],
      ),
    );
  }
}
