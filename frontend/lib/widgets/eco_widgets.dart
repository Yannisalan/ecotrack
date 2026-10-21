import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reference card: rounded-3xl, soft border, surface background.
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = context.hairline;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(EcoTheme.cardRadius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(EcoTheme.cardRadius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Small uppercase label used above sections (reference `text-xs uppercase`).
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.label,
    this.icon,
    this.trailing,
  });

  final String label;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: EcoColors.brand),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: context.muted,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Reference pill toggle used for period / category selection.
class PillSegmented<T> extends StatelessWidget {
  const PillSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.labelOf,
  });

  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T)? labelOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? EcoColors.darkBg : const Color(0xFFE8F3ED),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final selected = option == value;
          return GestureDetector(
            onTap: () => onChanged(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? EcoColors.brand : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                labelOf?.call(option) ?? option.toString(),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : context.muted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Chip used for filters and statuses.
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? EcoColors.brand;
    final bg = selected
        ? accent
        : (context.isDark
              ? EcoColors.darkSurface
              : theme.colorScheme.surface);
    final fg = selected ? Colors.white : (color ?? context.muted);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? accent : context.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? Colors.white : fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reference "hero" panel: emerald gradient with soft glow.
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
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(EcoTheme.cardRadius),
        gradient:
            gradient ??
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
            ),
      ),
      child: child,
    );
  }
}

/// Icon in a tinted rounded square (reference list rows / stat cards).
class TintedIcon extends StatelessWidget {
  const TintedIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize = 20,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

/// Thin rounded progress bar (goal cards, pillar bars).
class EcoProgressBar extends StatelessWidget {
  const EcoProgressBar({
    super.key,
    required this.value,
    this.color = EcoColors.brand,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: context.isDark
            ? EcoColors.darkBg
            : const Color(0xFFE8F3ED),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

void ecoSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? EcoColors.rose : const Color(0xFF0F172A),
      ),
    );
}
