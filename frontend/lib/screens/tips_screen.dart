import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/eco_widgets.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  static const List<_Tip> _tips = [
    _Tip(1, 'Walk or cycle for trips under 2 km instead of driving.', 'transport'),
    _Tip(2, 'Use public transport (bus, train, metro) for longer commutes.', 'transport'),
    _Tip(3, 'Carpool or share rides to split emissions per person.', 'transport'),
    _Tip(4, 'Combine errands into one trip to avoid multiple cold starts.', 'transport'),
    _Tip(5, 'Keep tires properly inflated and service your car to cut fuel use.', 'transport'),
    _Tip(6, 'Fly less — take the train for short-haul routes and bundle flights when you must fly.', 'transport'),
    _Tip(7, 'Switch to LED bulbs — they use up to 85% less energy than incandescent.', 'energy'),
    _Tip(8, 'Turn off lights and unplug chargers when not in use to stop phantom loads.', 'energy'),
    _Tip(9, 'Wash clothes in cold water and air-dry instead of using a dryer.', 'energy'),
    _Tip(10, 'Set your thermostat 1–2°C lower in winter and higher in summer.', 'energy'),
    _Tip(11, 'Choose energy-efficient appliances (A+++ / Energy Star rated).', 'energy'),
    _Tip(12, 'Install a smart power strip to kill standby power automatically.', 'energy'),
    _Tip(13, 'Fix leaky taps and running toilets — a drip can waste thousands of litres a year.', 'water'),
    _Tip(14, 'Take shorter showers and install a low-flow showerhead.', 'water'),
    _Tip(15, 'Turn off the tap while brushing teeth or shaving.', 'water'),
    _Tip(16, 'Water plants early morning or evening to reduce evaporation.', 'water'),
    _Tip(17, 'Collect rainwater for gardens and washing.', 'water'),
    _Tip(18, 'Run dishwashers and washing machines only with full loads.', 'water'),
    _Tip(19, 'Refuse single-use plastics — carry a reusable bottle, bag, and cup.', 'waste'),
    _Tip(20, 'Recycle properly: paper, glass, metal, and plastics in the right bins.', 'waste'),
    _Tip(21, 'Compost food scraps to cut methane from landfills.', 'waste'),
    _Tip(22, 'Repair and repurpose items instead of replacing them.', 'waste'),
    _Tip(23, 'Buy second-hand or refurbished electronics and clothing.', 'waste'),
    _Tip(24, 'Avoid fast fashion — choose durable, timeless pieces.', 'waste'),
    _Tip(25, 'Eat more plant-based meals — beef and lamb are carbon-intensive.', 'food'),
    _Tip(26, 'Buy local and seasonal produce to cut transport emissions.', 'food'),
    _Tip(27, 'Plan meals to avoid food waste; store leftovers properly.', 'food'),
    _Tip(28, 'Grow some of your own herbs and vegetables.', 'food'),
    _Tip(29, 'Plant trees or support reforestation to absorb CO2.', 'community'),
    _Tip(30, 'Switch to a green/renewable energy tariff and support community climate action.', 'community'),
  ];

  static const Map<String, IconData> _cat = {
    'transport': Icons.directions_bus_outlined,
    'energy': Icons.flash_on_outlined,
    'water': Icons.water_drop_outlined,
    'waste': Icons.delete_outline,
    'food': Icons.restaurant_outlined,
    'community': Icons.people_outlined,
  };

  Color _catColor(String c) {
    switch (c) {
      case 'transport': return EcoColors.mobility;
      case 'energy': return EcoColors.energy;
      case 'water': return EcoColors.water;
      case 'waste': return EcoColors.waste;
      case 'food': return EcoColors.energy;
      case 'community': return EcoColors.brand;
      default: return EcoColors.lightMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tips')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
        children: [
          for (final t in _tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EcoCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TintedIcon(
                      icon: _cat[t.category] ?? Icons.lightbulb_outline,
                      color: _catColor(t.category),
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${t.index}. ${t.text}',
                        style: theme.textTheme.bodyMedium,
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
}

class _Tip {
  final int index;
  final String text;
  final String category;
  const _Tip(this.index, this.text, this.category);
}
