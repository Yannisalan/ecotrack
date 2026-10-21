import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// One entry per backend activity category.
class EcoCategoryMeta {
  const EcoCategoryMeta({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.sdg,
    required this.sdgTitle,
  });

  final String key; // backend category name
  final String label; // display name (reference pillar name)
  final IconData icon;
  final Color color;
  final int sdg; // UN Sustainable Development Goal number
  final String sdgTitle;
}

const ecoCategories = <EcoCategoryMeta>[
  EcoCategoryMeta(
    key: 'transport',
    label: 'Mobility',
    icon: Icons.directions_car_outlined,
    color: EcoColors.mobility,
    sdg: 13,
    sdgTitle: 'Climate action',
  ),
  EcoCategoryMeta(
    key: 'electricity',
    label: 'Energy',
    icon: Icons.bolt_outlined,
    color: EcoColors.energy,
    sdg: 7,
    sdgTitle: 'Clean energy',
  ),
  EcoCategoryMeta(
    key: 'water',
    label: 'Water',
    icon: Icons.water_drop_outlined,
    color: EcoColors.water,
    sdg: 6,
    sdgTitle: 'Clean water',
  ),
  EcoCategoryMeta(
    key: 'waste',
    label: 'Waste',
    icon: Icons.recycling_outlined,
    color: EcoColors.waste,
    sdg: 12,
    sdgTitle: 'Responsible consumption',
  ),
];

EcoCategoryMeta ecoCategory(String? key) => ecoCategories.firstWhere(
  (c) => c.key == key,
  orElse: () => const EcoCategoryMeta(
    key: 'other',
    label: 'Other',
    icon: Icons.eco_outlined,
    color: EcoColors.brand,
    sdg: 13,
    sdgTitle: 'Climate action',
  ),
);

const _typeLabels = <String, String>{
  'walk': 'Walking',
  'bicycle': 'Cycling',
  'motorbike': 'Motorbike',
  'car_petrol': 'Car (petrol)',
  'car_diesel': 'Car (diesel)',
  'car_electric': 'Car (electric)',
  'bus': 'Bus',
  'train': 'Train',
  'metro': 'Metro',
  'flight': 'Flight',
  'grid': 'Grid power',
  'solar': 'Solar power',
  'tap': 'Tap water',
  'rainwater': 'Rainwater',
  'landfill': 'Landfill waste',
  'recycling': 'Recycling',
  'compost': 'Composting',
  'reuse': 'Reusing',
};

String ecoTypeLabel(String? type) {
  if (type == null || type.isEmpty) return 'Activity';
  final known = _typeLabels[type];
  if (known != null) return known;
  final words = type.split('_').where((w) => w.isNotEmpty);
  final pretty = words
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
  return pretty.isEmpty ? type : pretty;
}

Color ecoGradeColor(String? grade) => switch (grade) {
  'Excellent' => EcoColors.brand,
  'Good' => EcoColors.sky,
  'Fair' => EcoColors.amber,
  'Needs work' => EcoColors.rose,
  _ => EcoColors.brand,
};

String ecoFormatKg(num? kg) {
  final v = (kg ?? 0).toDouble();
  if (v.abs() >= 100) return v.toStringAsFixed(0);
  if (v.abs() >= 10) return v.toStringAsFixed(1);
  return v.toStringAsFixed(2);
}

String ecoFormatQty(num? value) {
  final v = (value ?? 0).toDouble();
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}

String ecoFormatDate(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final today = DateTime.now();
  final days = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// 1 tree absorbs roughly 21 kg CO2 per year, so ~1.83 kg per month.
const ecoKgPerTreeMonth = 1.83;

/// Average petrol car emits ~0.192 kg CO2 per km (matches backend factor).
const ecoKgPerCarKm = 0.192;
