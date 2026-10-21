import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// Sticky header: leaf logo, "EcoTrack" + the current tab's subtitle, then the
/// streak chip, theme toggle and avatar.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.subtitle,
    required this.streak,
    required this.onProfileTap,
    this.unread = 0,
    this.onNotificationsTap,
  });

  final String subtitle;
  final int streak;
  final VoidCallback onProfileTap;
  final int unread;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final name = context.watch<AuthProvider>().userName;

    return Container(
      decoration: BoxDecoration(
        color: eco.background,
        border: Border(bottom: BorderSide(color: eco.border)),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 10,
        left: 16,
        right: 12,
        bottom: 10,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [eco.primary, eco.secondary]),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [BoxShadow(color: eco.glow, blurRadius: 10)],
            ),
            child: Icon(Icons.eco, color: eco.onPrimary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EcoTrack',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: eco.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (streak > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: eco.warning.withValues(alpha: eco.brightness == Brightness.dark ? 0.2 : 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department, size: 15, color: eco.warning),
                  const SizedBox(width: 3),
                  Text(
                    '$streak',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: eco.warning,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 6),
          if (onNotificationsTap != null)
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Notifications',
                  visualDensity: VisualDensity.compact,
                  onPressed: onNotificationsTap,
                  icon: Icon(
                    unread > 0
                        ? Icons.notifications
                        : Icons.notifications_outlined,
                    size: 20,
                    color: unread > 0 ? eco.primary : eco.textSecondary,
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 15),
                      decoration: BoxDecoration(
                        color: eco.danger,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: eco.background, width: 1.5),
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          IconButton(
            tooltip: 'Theme',
            visualDensity: VisualDensity.compact,
            onPressed: () => showThemeModeSheet(context, settings),
            icon: Icon(
              switch (settings.themeMode) {
                ThemeMode.system => Icons.brightness_auto_outlined,
                ThemeMode.light => Icons.light_mode_outlined,
                ThemeMode.dark => Icons.dark_mode_outlined,
              },
              size: 20,
              color: eco.textSecondary,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onProfileTap,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: eco.primary.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: eco.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet offering the three theme modes. Reused by the header icon and
/// the profile screen so both stay in sync.
Future<void> showThemeModeSheet(
  BuildContext context,
  SettingsProvider settings,
) {
  final eco = context.eco;
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: eco.borderStrong,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Icon(Icons.palette_outlined, size: 18, color: eco.primary),
                const SizedBox(width: 8),
                Text(
                  'Appearance',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (m) {
              if (m != null) settings.setThemeMode(m);
              Navigator.of(sheetContext).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in const [
                  (ThemeMode.system, 'System', 'Follow your device setting', Icons.brightness_auto_outlined),
                  (ThemeMode.light, 'Light', 'Lab-clean mint', Icons.light_mode_outlined),
                  (ThemeMode.dark, 'Dark', 'Bioluminescent lab', Icons.dark_mode_outlined),
                ])
                  RadioListTile<ThemeMode>(
                    value: mode.$1,
                    title: Text(mode.$2),
                    subtitle: Text(mode.$3),
                    secondary: Icon(
                      mode.$4,
                      color: settings.themeMode == mode.$1
                          ? eco.primary
                          : eco.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
