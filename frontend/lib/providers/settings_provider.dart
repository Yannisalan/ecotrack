import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UnitSystem { metric, imperial }

/// Theme mode + unit preference, both persisted locally.
class SettingsProvider extends ChangeNotifier {
  static const _themeKey = 'pref_theme_mode';
  static const _unitsKey = 'pref_units';

  ThemeMode themeMode = ThemeMode.system;
  UnitSystem units = UnitSystem.metric;
  bool loaded = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode = _themeFrom(prefs.getString(_themeKey));
    units = prefs.getString(_unitsKey) == 'imperial'
        ? UnitSystem.imperial
        : UnitSystem.metric;
    loaded = true;
    notifyListeners();
  }

  static ThemeMode _themeFrom(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  /// Flips between light and dark (reference header toggle behaviour).
  Future<void> toggleTheme(bool currentlyDark) =>
      setThemeMode(currentlyDark ? ThemeMode.light : ThemeMode.dark);

  Future<void> setUnits(UnitSystem value) async {
    units = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _unitsKey,
      value == UnitSystem.imperial ? 'imperial' : 'metric',
    );
  }

  // ---- Unit conversion (backend always speaks km / kWh / litres / kg) ------

  bool get isImperial => units == UnitSystem.imperial;

  /// Backend value -> what the user types/sees.
  double toDisplay(double value, String? backendUnit) => switch (backendUnit) {
    'km' => isImperial ? value * 0.621371 : value,
    'litres' => isImperial ? value * 0.264172 : value,
    'kg' => isImperial ? value * 2.20462 : value,
    _ => value,
  };

  /// What the user typed -> backend value.
  double toBackend(double value, String? backendUnit) => switch (backendUnit) {
    'km' => isImperial ? value / 0.621371 : value,
    'litres' => isImperial ? value / 0.264172 : value,
    'kg' => isImperial ? value / 2.20462 : value,
    _ => value,
  };

  String displayUnit(String? backendUnit) => switch (backendUnit) {
    'km' => isImperial ? 'miles' : 'km',
    'litres' => isImperial ? 'gal' : 'litres',
    'kg' => isImperial ? 'lb' : 'kg',
    'kWh' => 'kWh',
    _ => backendUnit ?? '',
  };

  String displayUnitShort(String? backendUnit) => switch (backendUnit) {
    'km' => isImperial ? 'mi' : 'km',
    'litres' => isImperial ? 'gal' : 'L',
    'kg' => isImperial ? 'lb' : 'kg',
    'kWh' => 'kWh',
    _ => backendUnit ?? '',
  };

  String unitsLabel() =>
      isImperial ? 'Showing miles, gallons, pounds and kWh.' : 'Showing km, litres, kilograms and kWh.';
}
