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

/// Fixed bottom navigation matching the reference (5 tabs, emerald active).
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
    final theme = Theme.of(context);
    final dark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: (dark ? EcoColors.darkSurface : Colors.white).withValues(
          alpha: 0.96,
        ),
        border: Border.all(color: context.hairline),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.4 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
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
    final color = selected ? EcoColors.brand : context.muted;
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

/// Floating "Log Action" pill that sits above the nav bar (reference FAB).
class LogActionFab extends StatelessWidget {
  const LogActionFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EcoColors.brand,
      borderRadius: BorderRadius.circular(999),
      elevation: 6,
      shadowColor: EcoColors.brand.withValues(alpha: 0.6),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.white, size: 19),
              SizedBox(width: 6),
              Text(
                'Log Action',
                style: TextStyle(
                  color: Colors.white,
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
