import 'package:flutter/material.dart';

/// "Bio-tech neon" design tokens, defined once as a [ThemeExtension].
///
/// Dark and light instances share identical shape/spacing/motion; only the
/// colour values change, so both modes read as the same brand.
///
/// Usage: `Theme.of(context).extension<EcoColors>()!` or the [EcoColorX]
/// helpers (`context.eco`, `context.muted`, ...). Never hardcode colours
/// elsewhere in the app.
@immutable
class EcoColors extends ThemeExtension<EcoColors> {
  const EcoColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.accent,
    required this.warning,
    required this.danger,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
    required this.borderStrong,
    required this.glow,
    required this.fieldFill,
    required this.track,
    required this.overlay,
    required this.shadow,
    required this.categoryTransport,
    required this.categoryEnergy,
    required this.categoryWater,
    required this.categoryWaste,
    required this.gradeExcellent,
    required this.gradeGood,
    required this.gradeFair,
    required this.gradePoor,
    required this.biomeSky,
    required this.biomeMint,
    required this.biomeDeep,
    required this.sunGlow,
    required this.snackBackground,
    required this.snackForeground,
    required this.scrim,
  });

  /// Active [Brightness] this token set targets.
  final Brightness brightness;

  // ---- Surfaces -----------------------------------------------------------
  final Color background;
  final Color surface;
  final Color surfaceElevated;

  // ---- Brand --------------------------------------------------------------
  /// Bio-green. Filled buttons / gauge arcs / chart fills. Never thin text on
  /// light backgrounds.
  final Color primary;

  /// Text/icon colour that sits on a [primary] (or other neon) fill.
  final Color onPrimary;

  /// Aqua accent for data highlights.
  final Color secondary;

  /// Spore violet — used sparingly.
  final Color accent;

  final Color warning;
  final Color danger;

  // ---- Text ---------------------------------------------------------------
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  // ---- Lines & effects ----------------------------------------------------
  /// Default hairline/component border (tinted with [primary]).
  final Color border;

  /// Emphasised border for focused/selected states.
  final Color borderStrong;

  /// Outer glow for cards, buttons, key metrics.
  final Color glow;

  /// Input fill.
  final Color fieldFill;

  /// Inactive track of gauges / progress bars / pills.
  final Color track;

  /// Translucent ink surface for hovered/selected neutral chips.
  final Color overlay;

  /// Card / nav shadow.
  final Color shadow;

  // ---- Category palette ---------------------------------------------------
  final Color categoryTransport; // aqua
  final Color categoryEnergy; // amber
  final Color categoryWater; // blue-aqua
  final Color categoryWaste; // green / violet

  // ---- Eco Score grades ---------------------------------------------------
  final Color gradeExcellent;
  final Color gradeGood;
  final Color gradeFair;
  final Color gradePoor;

  // ---- Biome illustration -------------------------------------------------
  final Color biomeSky;
  final Color biomeMint;
  final Color biomeDeep;
  final Color sunGlow;

  // ---- Snackbar -----------------------------------------------------------
  final Color snackBackground;
  final Color snackForeground;

  /// Modal barrier.
  final Color scrim;

  /// The bio-tech neon palette for dark backgrounds.
  static const dark = EcoColors(
    brightness: Brightness.dark,
    background: Color(0xFF050A0E),
    surface: Color(0xFF0B1519),
    surfaceElevated: Color(0xFF101F25),
    primary: Color(0xFF39FF88),
    onPrimary: Color(0xFF04130C),
    secondary: Color(0xFF19E6FF),
    accent: Color(0xFFA66CFF),
    warning: Color(0xFFFFC933),
    danger: Color(0xFFFF4D6D),
    textPrimary: Color(0xFFE8FFF4),
    textSecondary: Color(0xFF8FB5A6),
    textDisabled: Color(0xFF4A6358),
    border: Color(0x3339FF88), // primary @ 20%
    borderStrong: Color(0x6639FF88), // primary @ 40%
    glow: Color(0x4039FF88), // primary @ 25%
    fieldFill: Color(0xFF0B1519),
    track: Color(0xFF16292F),
    overlay: Color(0x14E8FFF4),
    shadow: Color(0x66000000),
    categoryTransport: Color(0xFF19E6FF),
    categoryEnergy: Color(0xFFFFC933),
    categoryWater: Color(0xFF38BDF8),
    categoryWaste: Color(0xFFA66CFF),
    gradeExcellent: Color(0xFF39FF88),
    gradeGood: Color(0xFF19E6FF),
    gradeFair: Color(0xFFFFC933),
    gradePoor: Color(0xFFFF4D6D),
    biomeSky: Color(0xFF102A3A),
    biomeMint: Color(0xFF145C4B),
    biomeDeep: Color(0xFF0A3B2C),
    sunGlow: Color(0xFFFFD166),
    snackBackground: Color(0xFF101F25),
    snackForeground: Color(0xFFE8FFF4),
    scrim: Color(0xB3050A0E),
  );

  /// Deepened palette for light backgrounds ("lab-clean with a soft neon glow").
  static const light = EcoColors(
    brightness: Brightness.light,
    background: Color(0xFFF3FBF7),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFE8F6EF),
    primary: Color(0xFF00B85C),
    onPrimary: Color(0xFF04130C),
    secondary: Color(0xFF0098B8),
    accent: Color(0xFF7A3FE0),
    warning: Color(0xFFC98A00),
    danger: Color(0xFFD6264A),
    textPrimary: Color(0xFF08221A),
    textSecondary: Color(0xFF3F6556),
    textDisabled: Color(0xFF8CA89B),
    border: Color(0x4000B85C), // primary @ 25%
    borderStrong: Color(0x7300B85C), // primary @ 45%
    glow: Color(0x2E00B85C), // primary @ 18%
    fieldFill: Color(0xFFFFFFFF),
    track: Color(0xFFDCEAE3),
    overlay: Color(0x0D08221A),
    shadow: Color(0x1A00B85C),
    categoryTransport: Color(0xFF0098B8),
    categoryEnergy: Color(0xFFC98A00),
    categoryWater: Color(0xFF0E7FA8),
    categoryWaste: Color(0xFF7A3FE0),
    gradeExcellent: Color(0xFF00A451),
    gradeGood: Color(0xFF0086A3),
    gradeFair: Color(0xFFA87200),
    gradePoor: Color(0xFFC11F41),
    biomeSky: Color(0xFF7FD8F0),
    biomeMint: Color(0xFF8FE6C0),
    biomeDeep: Color(0xFF2FA97C),
    sunGlow: Color(0xFFFFD166),
    snackBackground: Color(0xFF08221A),
    snackForeground: Color(0xFFE8FFF4),
    scrim: Color(0x7308221A),
  );

  /// Bright neon used only for fills/glows — safe as text on dark only.
  static const neonGreen = Color(0xFF39FF88);
  static const neonAqua = Color(0xFF19E6FF);

  @override
  EcoColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? accent,
    Color? warning,
    Color? danger,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? border,
    Color? borderStrong,
    Color? glow,
    Color? fieldFill,
    Color? track,
    Color? overlay,
    Color? shadow,
    Color? categoryTransport,
    Color? categoryEnergy,
    Color? categoryWater,
    Color? categoryWaste,
    Color? gradeExcellent,
    Color? gradeGood,
    Color? gradeFair,
    Color? gradePoor,
    Color? biomeSky,
    Color? biomeMint,
    Color? biomeDeep,
    Color? sunGlow,
    Color? snackBackground,
    Color? snackForeground,
    Color? scrim,
  }) {
    return EcoColors(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      glow: glow ?? this.glow,
      fieldFill: fieldFill ?? this.fieldFill,
      track: track ?? this.track,
      overlay: overlay ?? this.overlay,
      shadow: shadow ?? this.shadow,
      categoryTransport: categoryTransport ?? this.categoryTransport,
      categoryEnergy: categoryEnergy ?? this.categoryEnergy,
      categoryWater: categoryWater ?? this.categoryWater,
      categoryWaste: categoryWaste ?? this.categoryWaste,
      gradeExcellent: gradeExcellent ?? this.gradeExcellent,
      gradeGood: gradeGood ?? this.gradeGood,
      gradeFair: gradeFair ?? this.gradeFair,
      gradePoor: gradePoor ?? this.gradePoor,
      biomeSky: biomeSky ?? this.biomeSky,
      biomeMint: biomeMint ?? this.biomeMint,
      biomeDeep: biomeDeep ?? this.biomeDeep,
      sunGlow: sunGlow ?? this.sunGlow,
      snackBackground: snackBackground ?? this.snackBackground,
      snackForeground: snackForeground ?? this.snackForeground,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  EcoColors lerp(covariant ThemeExtension<EcoColors>? other, double t) {
    if (other is! EcoColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return EcoColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceElevated: c(surfaceElevated, other.surfaceElevated),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      secondary: c(secondary, other.secondary),
      accent: c(accent, other.accent),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textDisabled: c(textDisabled, other.textDisabled),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      glow: c(glow, other.glow),
      fieldFill: c(fieldFill, other.fieldFill),
      track: c(track, other.track),
      overlay: c(overlay, other.overlay),
      shadow: c(shadow, other.shadow),
      categoryTransport: c(categoryTransport, other.categoryTransport),
      categoryEnergy: c(categoryEnergy, other.categoryEnergy),
      categoryWater: c(categoryWater, other.categoryWater),
      categoryWaste: c(categoryWaste, other.categoryWaste),
      gradeExcellent: c(gradeExcellent, other.gradeExcellent),
      gradeGood: c(gradeGood, other.gradeGood),
      gradeFair: c(gradeFair, other.gradeFair),
      gradePoor: c(gradePoor, other.gradePoor),
      biomeSky: c(biomeSky, other.biomeSky),
      biomeMint: c(biomeMint, other.biomeMint),
      biomeDeep: c(biomeDeep, other.biomeDeep),
      sunGlow: c(sunGlow, other.sunGlow),
      snackBackground: c(snackBackground, other.snackBackground),
      snackForeground: c(snackForeground, other.snackForeground),
      scrim: c(scrim, other.scrim),
    );
  }
}

/// Ergonomic accessors for [EcoColors].
extension EcoColorX on BuildContext {
  EcoColors get eco => Theme.of(this).extension<EcoColors>()!;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Secondary text colour (was `context.muted`).
  Color get muted => eco.textSecondary;

  /// Default hairline border (was `context.hairline`).
  Color get hairline => eco.border;

  /// Reduced-motion awareness for animations.
  bool get reducedMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}
