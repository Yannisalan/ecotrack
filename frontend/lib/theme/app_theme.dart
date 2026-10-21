import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'eco_colors.dart';

export 'eco_colors.dart';

/// Typography scale. Display/headline/big numbers use a techy geometric font;
/// body copy uses Inter. Metrics use tabular figures.
class AppTextStyles {
  const AppTextStyles._();

  static TextTheme _base(Color textColor, Color muted) {
    final display = GoogleFonts.spaceGroteskTextTheme();
    final body = GoogleFonts.interTextTheme();

    TextStyle headline(TextStyle? s) => (s ?? const TextStyle()).copyWith(
      color: textColor,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    );

    return TextTheme(
      displayLarge: headline(display.displayLarge),
      displayMedium: headline(display.displayMedium),
      displaySmall: headline(display.displaySmall),
      headlineLarge: headline(display.headlineLarge),
      headlineMedium: headline(display.headlineMedium),
      headlineSmall: headline(display.headlineSmall),
      titleLarge: headline(display.titleLarge),
      titleMedium: (display.titleMedium ?? const TextStyle()).copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: (display.titleSmall ?? const TextStyle()).copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: (body.bodyLarge ?? const TextStyle()).copyWith(
        color: textColor,
      ),
      bodyMedium: (body.bodyMedium ?? const TextStyle()).copyWith(
        color: textColor,
      ),
      bodySmall: (body.bodySmall ?? const TextStyle()).copyWith(color: muted),
      labelLarge: (body.labelLarge ?? const TextStyle()).copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: (body.labelMedium ?? const TextStyle()).copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: (body.labelSmall ?? const TextStyle()).copyWith(color: muted),
    );
  }

  /// A tabular-figure style for CO2 values and the Eco Score (glow applied by
  /// the [GlowText] widget).
  static TextStyle metric(Color color, {double size = 28}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// Builds the full light/dark [ThemeData] plus the [EcoColors] extension.
class AppTheme {
  const AppTheme._();

  static const double cardRadius = 18;
  static const double smallRadius = 12;
  static const double fieldRadius = 14;

  static ThemeData light() => _build(EcoColors.light);
  static ThemeData dark() => _build(EcoColors.dark);

  static ThemeData _build(EcoColors eco) {
    final isDark = eco.brightness == Brightness.dark;
    final text = AppTextStyles._base(eco.textPrimary, eco.textSecondary);

    final scheme = ColorScheme(
      brightness: eco.brightness,
      primary: eco.primary,
      onPrimary: eco.onPrimary,
      secondary: eco.secondary,
      onSecondary: eco.onPrimary,
      error: eco.danger,
      onError: isDark ? const Color(0xFF2A060C) : Colors.white,
      surface: eco.surface,
      onSurface: eco.textPrimary,
      surfaceContainerHighest: eco.surfaceElevated,
      onSurfaceVariant: eco.textSecondary,
      outline: eco.border,
      outlineVariant: eco.border,
      shadow: eco.shadow,
      scrim: eco.scrim,
      inverseSurface: eco.snackBackground,
      onInverseSurface: eco.snackForeground,
      tertiary: eco.accent,
      onTertiary: eco.onPrimary,
    );

    final borderSide = BorderSide(color: eco.border);

    return ThemeData(
      useMaterial3: true,
      brightness: eco.brightness,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: eco.background,
      canvasColor: eco.background,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[eco],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: eco.textPrimary,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: eco.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: borderSide,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: eco.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: eco.textSecondary),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? (isDark ? eco.surfaceElevated : eco.track)
                : eco.primary,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? eco.textDisabled
                : eco.onPrimary,
          ),
          overlayColor: WidgetStatePropertyAll(eco.onPrimary.withValues(alpha: 0.12)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: WidgetStatePropertyAll(
            text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? eco.textDisabled : eco.primary,
          ),
          overlayColor: WidgetStatePropertyAll(eco.primary.withValues(alpha: 0.08)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color: s.contains(WidgetState.disabled) ? eco.border : eco.primary,
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? eco.textDisabled : eco.primary,
          ),
          overlayColor: WidgetStatePropertyAll(eco.primary.withValues(alpha: 0.08)),
          textStyle: WidgetStatePropertyAll(
            text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: eco.primary,
        foregroundColor: eco.onPrimary,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: borderSide,
        backgroundColor: eco.surface,
        selectedColor: eco.primary,
        labelStyle: text.labelMedium!,
        secondaryLabelStyle: text.labelMedium!.copyWith(color: eco.onPrimary),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: eco.fieldFill,
        hintStyle: text.bodyMedium?.copyWith(color: eco.textDisabled),
        labelStyle: text.bodyMedium?.copyWith(color: eco.textSecondary),
        errorStyle: text.bodySmall?.copyWith(color: eco.danger),
        prefixIconColor: eco.textSecondary,
        suffixIconColor: eco.textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: borderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: borderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: eco.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: eco.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: eco.danger, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: eco.border),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(eco.surfaceElevated),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(smallRadius)),
          ),
          side: WidgetStatePropertyAll(borderSide),
        ),
        textStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: eco.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: eco.surface,
        dragHandleColor: eco.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: eco.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: borderSide,
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: eco.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: eco.primary.withValues(alpha: isDark ? 0.18 : 0.12),
        headerForegroundColor: eco.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: borderSide,
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? eco.onPrimary : eco.textPrimary,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? eco.primary : Colors.transparent,
        ),
        todayForegroundColor: WidgetStatePropertyAll(eco.primary),
        todayBorder: BorderSide(color: eco.primary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: eco.snackBackground,
        contentTextStyle: text.bodyMedium?.copyWith(color: eco.snackForeground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(smallRadius)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: eco.primary,
        inactiveTrackColor: eco.track,
        thumbColor: eco.primary,
        overlayColor: eco.primary.withValues(alpha: 0.15),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: eco.primary,
        linearTrackColor: eco.track,
        circularTrackColor: eco.track,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? eco.onPrimary : eco.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? eco.primary : eco.track,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? eco.borderStrong : eco.border,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? eco.primary : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(eco.onPrimary),
        side: BorderSide(color: eco.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? eco.primary : eco.textSecondary,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: eco.textSecondary,
        textColor: eco.textPrimary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: eco.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: eco.border),
        ),
        textStyle: text.bodySmall?.copyWith(color: eco.textPrimary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: eco.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(smallRadius),
          side: borderSide,
        ),
        textStyle: text.bodyMedium,
      ),
    );
  }
}

/// Backwards-compatible alias; the design layer lives in [AppTheme] now.
typedef EcoTheme = AppTheme;
