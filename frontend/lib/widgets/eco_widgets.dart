import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'neon.dart';

export 'neon.dart'
    show
        NeonCard,
        NeonButton,
        NeonButtonVariant,
        NeonChip,
        NeonProgressBar,
        NeonProgressRing,
        NeonAppBar,
        GlowText,
        EmptyState,
        LoadingState,
        ErrorState,
        SectionLabel,
        TintedIcon,
        PillSegmented,
        ecoSnack;

/// Backwards-compatible alias for [NeonCard].
class EcoCard extends StatelessWidget {
  const EcoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => NeonCard(
        padding: padding,
        color: color,
        onTap: onTap,
        child: child,
      );
}

/// Backwards-compatible alias for [NeonChip].
class EcoChip extends StatelessWidget {
  const EcoChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => NeonChip(
        label: label,
        selected: selected,
        icon: icon,
        color: color,
        onTap: onTap,
      );
}

/// Backwards-compatible alias for [NeonProgressBar].
class EcoProgressBar extends StatelessWidget {
  const EcoProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) =>
      NeonProgressBar(value: value, color: color, height: height);
}

/// Hero panel: emerald→aqua neon gradient with dark text, token-aware per mode.
class GradientHero extends StatelessWidget {
  const GradientHero({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        gradient: gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: eco.brightness == Brightness.dark
                  ? [eco.primary, eco.secondary]
                  : [eco.primary, eco.secondary],
            ),
        boxShadow: [BoxShadow(color: eco.glow, blurRadius: 20, spreadRadius: -2)],
      ),
      child: child,
    );
  }
}
