import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// Sticky blurred header from the reference: leaf logo, "EcoTrack" + the
/// current tab's subtitle, then streak chip, theme toggle and avatar.
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
    final theme = Theme.of(context);
    final dark = context.isDark;
    final settings = context.watch<SettingsProvider>();
    final name = context.watch<AuthProvider>().userName;

    return Container(
      decoration: BoxDecoration(
        color: dark ? EcoColors.darkHeader : EcoColors.lightBg,
        border: Border(bottom: BorderSide(color: context.hairline)),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF34D399)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: EcoColors.brand.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.eco, color: Colors.white, size: 20),
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
                        color: context.muted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: EcoColors.amber.withValues(alpha: dark ? 0.2 : 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 15,
                        color: EcoColors.amber,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$streak',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: EcoColors.amber,
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
                        color: unread > 0 ? EcoColors.brand : context.muted,
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
                            color: EcoColors.rose,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: dark
                                  ? EcoColors.darkHeader
                                  : EcoColors.lightBg,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
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
                tooltip: dark ? 'Switch to light' : 'Switch to dark',
                visualDensity: VisualDensity.compact,
                onPressed: () => settings.toggleTheme(dark),
                icon: Icon(
                  dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 20,
                  color: context.muted,
                ),
              ),
              const SizedBox(width: 2),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onProfileTap,
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: EcoColors.brand.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: EcoColors.brand,
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
