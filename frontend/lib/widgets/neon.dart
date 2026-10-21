import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// NeonCard — glassy/white surface, thin neon border, optional outer glow.
// ---------------------------------------------------------------------------
class NeonCard extends StatelessWidget {
  const NeonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
    this.glow = false,
    this.accent,
    this.radius = AppTheme.cardRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool glow;
  final Color? accent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final tint = accent ?? eco.primary;
    final content = Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? eco.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: accent == null ? eco.border : tint.withValues(alpha: 0.4),
        ),
        boxShadow: glow
            ? [
                BoxShadow(color: eco.glow, blurRadius: 22, spreadRadius: -2),
                BoxShadow(
                  color: eco.shadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: eco.shadow,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        splashColor: tint.withValues(alpha: 0.10),
        highlightColor: tint.withValues(alpha: 0.06),
        child: content,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NeonButton — primary (neon fill) / secondary (outline).
// ---------------------------------------------------------------------------
enum NeonButtonVariant { primary, secondary }

class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = NeonButtonVariant.primary,
    this.loading = false,
    this.expand = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final NeonButtonVariant variant;
  final bool loading;
  final bool expand;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final accent = danger ? eco.danger : eco.primary;
    final enabled = onPressed != null && !loading;

    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == NeonButtonVariant.primary
                  ? eco.onPrimary
                  : accent,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final button = variant == NeonButtonVariant.primary
        ? FilledButton(
            onPressed: enabled ? onPressed : null,
            style: FilledButton.styleFrom(backgroundColor: accent),
            child: child,
          )
        : OutlinedButton(
            onPressed: enabled ? onPressed : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent),
            ),
            child: child,
          );

    if (!expand) return button;
    return Row(children: [Expanded(child: button)]);
  }
}

// ---------------------------------------------------------------------------
// GlowText — metric text with a soft coloured shadow (both modes).
// ---------------------------------------------------------------------------
class GlowText extends StatelessWidget {
  const GlowText(
    this.text, {
    super.key,
    this.size = 28,
    this.color,
    this.tabular = true,
    this.textAlign = TextAlign.start,
    this.maxLines,
  });

  final String text;
  final double size;
  final Color? color;
  final bool tabular;
  final TextAlign textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final c = color ?? eco.textPrimary;
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: AppTextStyles.metric(c, size: size).copyWith(
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
        shadows: [
          Shadow(
            color: c.withValues(alpha: eco.brightness == Brightness.dark ? 0.55 : 0.28),
            blurRadius: eco.brightness == Brightness.dark ? 16 : 8,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EmptyState / LoadingState / ErrorState
// ---------------------------------------------------------------------------
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: eco.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: eco.border),
              ),
              child: Icon(icon, size: 34, color: eco.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: eco.textSecondary),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: eco.primary),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: eco.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      title: 'Something went wrong',
      message: message,
      action: onRetry == null
          ? null
          : NeonButton(
              label: 'Try again',
              icon: Icons.refresh,
              onPressed: onRetry,
              variant: NeonButtonVariant.secondary,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// NeonProgressRing — animated radial gauge with a glowing arc.
// ---------------------------------------------------------------------------
class NeonProgressRing extends StatelessWidget {
  const NeonProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 8,
    this.color,
    this.child,
    this.animate = true,
  });

  final double value; // 0..1
  final double size;
  final double stroke;
  final Color? color;
  final Widget? child;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final c = color ?? eco.primary;
    final reduce = context.reducedMotion;
    Widget ring(double v) => SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(
                  progress: v,
                  track: eco.track,
                  color: c,
                  stroke: stroke,
                  glow: eco.glow,
                ),
              ),
              ?child,
            ],
          ),
        );

    if (!animate || reduce) return ring(value.clamp(0, 1));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => ring(v),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
    required this.stroke,
    required this.glow,
  });

  final double progress;
  final Color track;
  final Color color;
  final double stroke;
  final Color glow;

  static const _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    canvas.drawArc(
      rect,
      _start,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = glow,
    );
    canvas.drawArc(
      rect,
      _start,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.color != color ||
      old.stroke != stroke;
}

// ---------------------------------------------------------------------------
// NeonProgressBar — thin tokenised bar.
// ---------------------------------------------------------------------------
class NeonProgressBar extends StatelessWidget {
  const NeonProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: eco.track,
        valueColor: AlwaysStoppedAnimation(color ?? eco.primary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NeonChip / PillSegmented
// ---------------------------------------------------------------------------
class NeonChip extends StatelessWidget {
  const NeonChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.color,
    this.onTap,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final accent = color ?? eco.primary;
    final fg = selected ? eco.onPrimary : accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 10 : 12,
            vertical: dense ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: selected ? accent : eco.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? accent : accent.withValues(alpha: 0.35),
            ),
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
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: fg,
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
    final eco = context.eco;
    final theme = Theme.of(context);
    final reduce = context.reducedMotion;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: eco.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: eco.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final selected = option == value;
          return GestureDetector(
            onTap: () => onChanged(option),
            child: AnimatedContainer(
              duration: reduce
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? eco.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: selected
                    ? [BoxShadow(color: eco.glow, blurRadius: 12)]
                    : null,
              ),
              child: Text(
                labelOf?.call(option) ?? option.toString(),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? eco.onPrimary : eco.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SectionLabel / TintedIcon (token-aware)
// ---------------------------------------------------------------------------
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
    final eco = context.eco;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: eco.primary),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: eco.textSecondary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

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
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

// ---------------------------------------------------------------------------
// NeonAppBar — transparent, token-aware title/subtitle.
// ---------------------------------------------------------------------------
class NeonAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NeonAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final theme = Theme.of(context);
    return AppBar(
      automaticallyImplyLeading: leading == null ? true : false,
      leading: leading,
      titleSpacing: leading == null ? 0 : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: eco.textSecondary),
            ),
        ],
      ),
      actions: actions,
    );
  }
}

/// Token-aware snackbar helper.
void ecoSnack(BuildContext context, String message, {bool error = false}) {
  final eco = context.eco;
  final bg = error ? eco.danger : eco.snackBackground;
  final fg = error ? Colors.white : eco.snackForeground;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: fg)),
        backgroundColor: bg,
      ),
    );
}
