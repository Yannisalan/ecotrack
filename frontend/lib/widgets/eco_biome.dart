import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'eco_meta.dart';
import 'eco_score_gauge.dart';

/// Illustrated "Eco Biome" scene from the reference: sky->emerald gradient,
/// sun, rolling hills and a hotspot per pillar weighted by its real share.
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
    final active = pillars.where((p) => p.share > 0).toList()
      ..sort((a, b) => b.share.compareTo(a.share));
    final theme = Theme.of(context);

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(EcoTheme.cardRadius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF38BDF8), Color(0xFF6EE7B7), Color(0xFF059669)],
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
                color: const Color(0xFFFDE68A).withValues(alpha: 0.85),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFDE68A).withValues(alpha: 0.8),
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
              painter: _HillsPainter(),
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
                      color: Colors.white,
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
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                children: [
                  Icon(Icons.spa_outlined, size: 14, color: Color(0xFF047857)),
                  SizedBox(width: 5),
                  Text(
                    'Living Eco-Sanctuary',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF047857),
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
            color: pillar.color.withValues(alpha: 0.85),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.eco, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

class _HillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final far = Paint()..color = const Color(0xFF34D399).withValues(alpha: 0.55);
    final near = Paint()..color = const Color(0xFF047857).withValues(alpha: 0.85);

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
    canvas.drawPath(farPath, far);

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
    canvas.drawPath(nearPath, near);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
