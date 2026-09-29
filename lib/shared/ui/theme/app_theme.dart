import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand palette, taken from the app logo: a red check on charcoal.
  static const Color primaryColor = Color(0xFFE5323F); // Logo red
  static const Color brandCharcoal = Color(0xFF2D2F33); // Logo badge
  static const Color secondaryColor = Color(0xFF10B981); // Emerald
  static const Color accentColor = Color(0xFFF59E0B); // Amber

  /// Logo-matched scheme: red accents (fidelity keeps the logo's exact hue)
  /// over neutral charcoal greys instead of red-tinted surfaces.
  static ColorScheme brandScheme(Brightness brightness) {
    final accent = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final grey = ColorScheme.fromSeed(
      seedColor: brandCharcoal,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    );
    return accent.copyWith(
      secondary: grey.primary,
      onSecondary: grey.onPrimary,
      secondaryContainer: grey.primaryContainer,
      onSecondaryContainer: grey.onPrimaryContainer,
      surface: grey.surface,
      onSurface: grey.onSurface,
      onSurfaceVariant: grey.onSurfaceVariant,
      surfaceDim: grey.surfaceDim,
      surfaceBright: grey.surfaceBright,
      surfaceContainerLowest: grey.surfaceContainerLowest,
      surfaceContainerLow: grey.surfaceContainerLow,
      surfaceContainer: grey.surfaceContainer,
      surfaceContainerHigh: grey.surfaceContainerHigh,
      surfaceContainerHighest: grey.surfaceContainerHighest,
      outline: grey.outline,
      outlineVariant: grey.outlineVariant,
      inverseSurface: grey.inverseSurface,
      onInverseSurface: grey.onInverseSurface,
      surfaceTint: Colors.transparent,
    );
  }

  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Colors.white;
  static const Color textLight = Color(0xFF0F172A);

  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color textDark = Color(0xFFF8FAFC);

  static const Color errorColor = Color(0xFFEF4444);

  static ThemeData get lightTheme {
    return createLightTheme(null);
  }

  static ThemeData get darkTheme {
    return createDarkTheme(null, isAmoled: false);
  }

  static ThemeData createLightTheme(ColorScheme? dynamicColorScheme) {
    final ColorScheme scheme =
        dynamicColorScheme ?? brandScheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.light().textTheme,
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    );
  }

  static ThemeData createDarkTheme(
    ColorScheme? dynamicColorScheme, {
    bool isAmoled = false,
  }) {
    final ColorScheme scheme =
        dynamicColorScheme ?? brandScheme(Brightness.dark);

    final bgColor = isAmoled ? Colors.black : scheme.surface;
    final surfaceColor = isAmoled ? Colors.black : scheme.surfaceContainerLow;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(surface: bgColor),
      scaffoldBackgroundColor: bgColor,
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: isAmoled ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isAmoled ? BorderSide(color: Colors.white24) : BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    );
  }
}
