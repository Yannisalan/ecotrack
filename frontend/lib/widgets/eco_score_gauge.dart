import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'eco_meta.dart';

class PillarSlice {
  const PillarSlice({
    required this.label,
    required this.color,
    required this.kg,
    required this.share,
  });

  final String label;
  final Color color;
  final double kg;
  final double share; // 0..1 of total footprint
}

/// 160px ring gauge. The ring is split by each pillar's real share of the
/// logged footprint; the centre shows the server-computed Eco Score + grade.
class EcoScoreGauge extends StatelessWidget {
  const EcoScoreGauge({
    super.key,
    required this.score,
    required this.grade,
    required this.pillars,
    this.size = 160,
    this.stroke = 12,
  });

  final num? score; // null when nothing logged in the period
  final String? grade;
  final List<PillarSlice> pillars;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasScore = score != null;
    final value = ((score ?? 0).toDouble()).clamp(0, 100) / 100;
    final gradeColor = ecoGradeColor(grade);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _GaugePainter(
              progress: value,
              slices: pillars,
              trackColor: context.isDark
                  ? EcoColors.darkBg
                  : const Color(0xFFE8F3ED),
              accent: EcoColors.brand,
              stroke: stroke,
              dimmed: !hasScore,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasScore)
                Text(
                  '${(score!.toDouble()).round()}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                )
              else
                Icon(Icons.eco_outlined, size: 30, color: context.muted),
              const SizedBox(height: 4),
              Text(
                'Eco Score',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.muted,
                  letterSpacing: 0.3,
                ),
              ),
              if (hasScore && grade != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: gradeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    grade!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: gradeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.slices,
    required this.trackColor,
    required this.accent,
    required this.stroke,
    required this.dimmed,
  });

  final double progress;
  final List<PillarSlice> slices;
  final Color trackColor;
  final Color accent;
  final double stroke;
  final bool dimmed;

  static const _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final totalShare = slices.fold<double>(0, (sum, s) => sum + s.share);

    if (dimmed || totalShare <= 0) {
      final plain = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: dimmed ? 0.25 : 0.85);
      canvas.drawArc(rect, _start, math.pi * 2 * progress, false, plain);
      return;
    }

    // Segmented ring: each pillar occupies its share of the circle, with a
    // small gap so the four pillars read as separate arcs.
    const gap = 0.055;
    var angle = _start;
    for (final slice in slices) {
      if (slice.share <= 0) continue;
      final sweep = math.pi * 2 * (slice.share / totalShare) - gap;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = slice.color.withValues(alpha: 0.35 + 0.65 * progress);
      canvas.drawArc(rect, angle + gap / 2, sweep, false, paint);
      angle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress ||
      old.dimmed != dimmed ||
      old.trackColor != trackColor ||
      old.slices != slices;
}
