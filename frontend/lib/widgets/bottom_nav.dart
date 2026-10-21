import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EcoNavItem {
  const EcoNavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const ecoNavItems = <EcoNavItem>[
  EcoNavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
  EcoNavItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Analytics'),
  EcoNavItem(Icons.lightbulb_outline, Icons.lightbulb_rounded, 'Insights'),
  EcoNavItem(Icons.flag_outlined, Icons.flag_rounded, 'Goals'),
  EcoNavItem(Icons.person_outline, Icons.person_rounded, 'You'),
];

/// Floating bottom navigation (5 tabs, neon active).
class EcoBottomNav extends StatelessWidget {
  const EcoBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: eco.surface.withValues(alpha: 0.96),
        border: Border.all(color: eco.border),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: eco.shadow, blurRadius: 12, offset: const Offset(0, 2))],
      ),
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 8,
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            for (var i = 0; i < ecoNavItems.length; i++)
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(32),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(32),
                    onTap: () => onChanged(i),
                    child: _NavButton(
                      item: ecoNavItems[i],
                      selected: i == index,
                      textStyle: theme.textTheme.labelSmall!,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.textStyle,
  });

  final EcoNavItem item;
  final bool selected;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final color = selected ? eco.primary : eco.textSecondary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(selected ? item.activeIcon : item.icon, size: 22, color: color),
        const SizedBox(height: 3),
        Text(
          item.label,
          style: textStyle.copyWith(
            color: color,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

/// Floating "Log Action" pill that sits above the nav bar.
class LogActionFab extends StatelessWidget {
  const LogActionFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    return Material(
      color: eco.primary,
      borderRadius: BorderRadius.circular(999),
      elevation: 6,
      shadowColor: eco.glow,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: eco.onPrimary, size: 19),
              const SizedBox(width: 6),
              Text(
                'Log Action',
                style: TextStyle(
                  color: eco.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
