import 'package:flutter/material.dart';

/// Design tokens copied from the reference React app (`src/index.css`).
/// Light: bg #F4FBF7 / text #0F172A. Dark: bg #08120D / surface #0E2018.
class EcoColors {
  const EcoColors._();

  static const brand = Color(0xFF10B981); // emerald-600
  static const brandDark = Color(0xFF0E9F6E);
  static const brandLight = Color(0xFF34D399);

  static const mobility = Color(0xFF10B981);
  static const energy = Color(0xFFF59E0B);
  static const water = Color(0xFF0284C7);
  static const waste = Color(0xFFD97706);

  static const lightBg = Color(0xFFF4FBF7);
  static const lightSurface = Colors.white;
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightText = Color(0xFF0F172A);
  static const lightMuted = Color(0xFF64748B);

  static const darkBg = Color(0xFF08120D);
  static const darkSurface = Color(0xFF0E2018);
  static const darkHeader = Color(0xFF0A1812);
  static const darkBorder = Color(0xFF133F2E);
  static const darkText = Color(0xFFF1F5F9);
  static const darkMuted = Color(0xFF94A3B8);

  static const sky = Color(0xFF0EA5E9);
  static const amber = Color(0xFFF59E0B);
  static const rose = Color(0xFFF43F5E);
}

class EcoTheme {
  const EcoTheme._();

  static const double cardRadius = 24;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: EcoColors.brand,
      brightness: Brightness.light,
    ).copyWith(
      primary: EcoColors.brand,
      onPrimary: Colors.white,
      surface: EcoColors.lightSurface,
      onSurface: EcoColors.lightText,
    );
    return _base(scheme).copyWith(scaffoldBackgroundColor: EcoColors.lightBg);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: EcoColors.brand,
      brightness: Brightness.dark,
    ).copyWith(
      primary: EcoColors.brand,
      onPrimary: Colors.white,
      surface: EcoColors.darkSurface,
      onSurface: EcoColors.darkText,
    );
    return _base(scheme).copyWith(scaffoldBackgroundColor: EcoColors.darkBg);
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: scheme.brightness == Brightness.light
                ? EcoColors.lightBorder
                : EcoColors.darkBorder,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.brightness == Brightness.light
            ? EcoColors.lightBorder
            : EcoColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: EcoColors.brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
          side: BorderSide(
            color: scheme.brightness == Brightness.light
                ? EcoColors.lightBorder
                : EcoColors.darkBorder,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: EcoColors.brand),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(
          color: scheme.brightness == Brightness.light
              ? EcoColors.lightBorder
              : EcoColors.darkBorder,
        ),
        backgroundColor: scheme.surface,
        selectedColor: EcoColors.brand,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.brightness == Brightness.light
            ? Colors.white
            : EcoColors.darkBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.brightness == Brightness.light
                ? EcoColors.lightBorder
                : EcoColors.darkBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.brightness == Brightness.light
                ? EcoColors.lightBorder
                : EcoColors.darkBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: EcoColors.brand, width: 1.5),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF0F172A),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      sliderTheme: const SliderThemeData(activeTrackColor: EcoColors.brand),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: EcoColors.brand,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? EcoColors.brand
              : null,
        ),
      ),
    );
  }
}

/// Soft helpers used across the redesign.
extension EcoTextStyles on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get muted =>
      isDark ? EcoColors.darkMuted : EcoColors.lightMuted;
  Color get hairline =>
      isDark ? EcoColors.darkBorder : EcoColors.lightBorder;
}
