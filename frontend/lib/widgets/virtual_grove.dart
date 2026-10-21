import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'eco_widgets.dart';

/// Grove of one tree per 8 logged activities — the rule is shown to the user
/// instead of pretending trees come from avoided CO2 we do not measure.
class VirtualGrove extends StatelessWidget {
  const VirtualGrove({super.key, required this.activities, this.cap = 12});

  final int activities;
  final int cap;

  static const perTree = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trees = activities ~/ perTree;
    final intoCurrent = activities % perTree;
    final shown = trees < cap ? trees : cap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Virtual Grove',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: EcoColors.brand.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$trees ${trees == 1 ? 'tree' : 'trees'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: EcoColors.brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '1 tree for every $perTree logged activities',
          style: theme.textTheme.bodySmall?.copyWith(color: context.muted),
        ),
        const SizedBox(height: 12),
        if (trees == 0)
          EcoCard(
            child: Row(
              children: [
                const TintedIcon(
                  icon: Icons.park_outlined,
                  color: EcoColors.brand,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your grove is empty. Log activities to plant your first tree.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.muted,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < shown; i++) _TreeTile(index: i),
              if (trees > shown)
                Container(
                  width: 62,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? EcoColors.darkBg
                        : const Color(0xFFE8F3ED),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '+${trees - shown}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: context.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: EcoProgressBar(value: intoCurrent / perTree),
            ),
            const SizedBox(width: 10),
            Text(
              '$intoCurrent/$perTree to next tree',
              style: theme.textTheme.labelSmall?.copyWith(
                color: context.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TreeTile extends StatelessWidget {
  const _TreeTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const tones = [
      EcoColors.brand,
      Color(0xFF34D399),
      Color(0xFF0E9F6E),
      Color(0xFF059669),
    ];
    final tone = tones[index % tones.length];
    return Container(
      width: 62,
      height: 76,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: context.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.park, color: tone, size: 26),
          const SizedBox(height: 4),
          Text(
            '#${index + 1}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
