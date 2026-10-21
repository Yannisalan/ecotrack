import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'eco_meta.dart';
import 'eco_score_gauge.dart';

/// Illustrated "Eco Biome" scene: sky→emerald gradient, sun, rolling hills and
/// a hotspot per pillar weighted by its real share. Colours come from tokens
/// so the scene inverts correctly between modes.
class EcoBiome extends StatelessWidget {
  const EcoBiome({
    super.key,
    required this.pillars,
    this.height = 200,
  });

  final List<PillarSlice> pillars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final active = pillars.where((p) => p.share > 0).toList()
      ..sort((a, b) => b.share.compareTo(a.share));
    final theme = Theme.of(context);

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [eco.biomeSky, eco.biomeMint, eco.biomeDeep],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: eco.sunGlow.withValues(alpha: 0.85),
                boxShadow: [
                  BoxShadow(
                    color: eco.sunGlow.withValues(alpha: 0.8),
                    blurRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(
              size: Size(double.infinity, height * 0.55),
              painter: _HillsPainter(
                far: eco.biomeMint.withValues(alpha: 0.55),
                near: eco.biomeDeep.withValues(alpha: 0.85),
              ),
            ),
          ),
          if (active.isEmpty)
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    'Log an activity to grow your biome',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: eco.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          for (var i = 0; i < active.length; i++)
            _hotspot(context, active[i], i, active.length),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: eco.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: eco.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.spa_outlined, size: 14, color: eco.primary),
                  const SizedBox(width: 5),
                  Text(
                    'Living Eco-Sanctuary',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: eco.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hotspot(
    BuildContext context,
    PillarSlice pillar,
    int index,
    int count,
  ) {
    final eco = context.eco;
    final base = 0.22 + 0.5 * (index / (count == 0 ? 1 : count));
    return Positioned(
      left: 24.0 + (index * 62) % 250,
      bottom: 26 + base * 70,
      child: Tooltip(
        message: '${pillar.label}: ${ecoFormatKg(pillar.kg)} kg CO₂',
        child: Container(
          width: 34 + pillar.share * 26,
          height: 34 + pillar.share * 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pillar.color.withValues(alpha: 0.9),
            border: Border.all(color: eco.surface, width: 2),
            boxShadow: [
              BoxShadow(
                color: eco.shadow,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(Icons.eco, color: eco.onPrimary, size: 16),
        ),
      ),
    );
  }
}

class _HillsPainter extends CustomPainter {
  _HillsPainter({required this.far, required this.near});

  final Color far;
  final Color near;

  @override
  void paint(Canvas canvas, Size size) {
    final farPaint = Paint()..color = far;
    final nearPaint = Paint()..color = near;

    final farPath = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.1,
        size.width * 0.62,
        size.height * 0.45,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.7,
        size.width,
        size.height * 0.4,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(farPath, farPaint);

    final nearPath = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.5,
        size.width * 0.7,
        size.height * 0.78,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.92,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(nearPath, nearPaint);
  }

  @override
  bool shouldRepaint(_HillsPainter old) => old.far != far || old.near != near;
}
