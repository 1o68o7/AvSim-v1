import 'package:flutter/material.dart';

/// Technical Nautical Deck (Volt) — Stitch `17394974384541320335`.
///
/// Source of truth: project designMd « Technical Nautical Deck ».
/// CTA / live / pacing = [volt]. Alerte gîte / maintenance / EN FILE = [amber].
/// Bâbord = [babord] crimson, Tribord = [tribord] emerald. Pas de glow.
abstract final class DeckColors {
  // —— Foundation (OLED) ——
  static const Color bg = Color(0xFF0A0A0A);
  static const Color bgTactical = Color(0xFF0B0E12);
  static const Color surface = Color(0xFF111418);
  static const Color surfaceHigh = Color(0xFF181D24);
  static const Color surfaceHighest = Color(0xFF2A2A2A);
  static const Color hairline = Color(0xFF2A2F36);
  static const Color hairlineMuted = Color(0xFF22262C);
  static const Color borderElevated = Color(0xFF3A414B);

  // —— Text ——
  static const Color text = Color(0xFFF4F6F8);
  static const Color label = Color(0xFF8C96A5);
  static const Color muted = Color(0xFF8C96A5);
  static const Color disabled = Color(0xFF414955);

  // —— Accents ——
  /// Volt Strike — CTA, pacing, active telemetry, tab indicator.
  static const Color volt = Color(0xFFD6FF3C);
  static const Color onVolt = Color(0xFF0A0A0A);

  /// Maintenance / warning / EN FILE / gîte alert (not CTA).
  static const Color amber = Color(0xFFE8C547);
  static const Color alert = Color(0xFFE8C547);
  static const Color onAlert = Color(0xFF0A0A0A);
  static const Color amberWash = Color(0xFF241E0D);

  /// Starboard / Tribord.
  static const Color tribord = Color(0xFF46C275);
  static const Color tribordWash = Color(0xFF0F2418);
  /// Bandeau alerte « trop tribords » — vert foncé (libellés restent [tribord]).
  static const Color tribordAlert = Color(0xFF0F5C32);

  /// Port / Bâbord + critical / MOCK.
  static const Color babord = Color(0xFFE05353);
  static const Color babordWash = Color(0xFF261414);
  static const Color error = Color(0xFFE05353);

  // —— Honest status chip fills ——
  static const Color chipLocalBg = Color(0xFF181D24);
}

/// Radii — Technical Nautical Deck (no square Hangar corners).
abstract final class DeckRadii {
  static const double chip = 6;
  static const double button = 12;
  static const double card = 14;
  static const double cardLg = 16;

  static BorderRadius get chipAll => BorderRadius.circular(chip);
  static BorderRadius get buttonAll => BorderRadius.circular(button);
  static BorderRadius get cardAll => BorderRadius.circular(card);
}

/// Typography helpers — Inter (UI) + JetBrains Mono (metrics).
abstract final class DeckType {
  static const String ui = 'Inter';
  static const String mono = 'JetBrainsMono';

  static TextStyle labelMono({
    Color color = DeckColors.label,
    double size = 11,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        fontWeight: weight,
        height: 14 / 11,
        letterSpacing: 0.66,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle metric({
    double size = 32,
    FontWeight weight = FontWeight.w600,
    Color color = DeckColors.text,
    double height = 1.125,
  }) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: size >= 40 ? -0.04 * size / 12 : -0.02 * size / 12,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle uiLabel({
    Color color = DeckColors.label,
    double size = 13,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(
        fontFamily: ui,
        fontSize: size,
        fontWeight: weight,
        height: 16 / 13,
        color: color,
      );
}

ThemeData buildDeckTheme() {
  const scheme = ColorScheme.dark(
    surface: DeckColors.bg,
    primary: DeckColors.volt,
    onPrimary: DeckColors.onVolt,
    secondary: DeckColors.tribord,
    onSecondary: Color(0xFF00391A),
    tertiary: DeckColors.babord,
    onTertiary: DeckColors.text,
    onSurface: DeckColors.text,
    outline: DeckColors.hairline,
    error: DeckColors.error,
    onError: DeckColors.text,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: DeckColors.bg,
    canvasColor: DeckColors.bg,
    fontFamily: DeckType.ui,
    appBarTheme: const AppBarTheme(
      backgroundColor: DeckColors.bg,
      foregroundColor: DeckColors.text,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: DeckType.ui,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: DeckColors.text,
      ),
    ),
    dividerColor: DeckColors.hairline,
    cardTheme: CardThemeData(
      color: DeckColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: DeckRadii.cardAll,
        side: const BorderSide(color: DeckColors.hairline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: DeckColors.volt,
        foregroundColor: DeckColors.onVolt,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: DeckRadii.buttonAll),
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(
          fontFamily: DeckType.ui,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: DeckColors.text,
        side: const BorderSide(color: DeckColors.hairline),
        shape: RoundedRectangleBorder(borderRadius: DeckRadii.buttonAll),
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(
          fontFamily: DeckType.ui,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: DeckColors.label,
        shape: RoundedRectangleBorder(borderRadius: DeckRadii.buttonAll),
        textStyle: const TextStyle(
          fontFamily: DeckType.ui,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DeckColors.surfaceHigh,
      enabledBorder: OutlineInputBorder(
        borderRadius: DeckRadii.buttonAll,
        borderSide: const BorderSide(color: DeckColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: DeckRadii.buttonAll,
        borderSide: const BorderSide(color: DeckColors.volt),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: DeckRadii.buttonAll,
        borderSide: const BorderSide(color: DeckColors.error),
      ),
      labelStyle: DeckType.uiLabel(),
      hintStyle: DeckType.uiLabel(color: DeckColors.disabled),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: DeckColors.chipLocalBg,
      side: const BorderSide(color: DeckColors.hairline),
      shape: RoundedRectangleBorder(borderRadius: DeckRadii.chipAll),
      labelStyle: DeckType.labelMono(),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: DeckColors.bgTactical,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: DeckType.ui,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: active ? DeckColors.volt : DeckColors.label,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return IconThemeData(
          color: active ? DeckColors.volt : DeckColors.label,
          size: 22,
        );
      }),
    ),
    textTheme: TextTheme(
      displayLarge: DeckType.metric(size: 48, weight: FontWeight.w700),
      displayMedium: DeckType.metric(size: 32),
      displaySmall: DeckType.metric(size: 20),
      headlineLarge: const TextStyle(
        fontFamily: DeckType.ui,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        letterSpacing: -0.64,
        color: DeckColors.text,
      ),
      headlineMedium: const TextStyle(
        fontFamily: DeckType.ui,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        letterSpacing: -0.24,
        color: DeckColors.text,
      ),
      headlineSmall: const TextStyle(
        fontFamily: DeckType.ui,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: DeckColors.text,
      ),
      bodyLarge: const TextStyle(
        fontFamily: DeckType.ui,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: DeckColors.text,
      ),
      bodyMedium: const TextStyle(
        fontFamily: DeckType.ui,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: DeckColors.text,
      ),
      bodySmall: const TextStyle(
        fontFamily: DeckType.ui,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: DeckColors.label,
      ),
      labelLarge: const TextStyle(
        fontFamily: DeckType.ui,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: DeckColors.text,
      ),
      labelSmall: DeckType.labelMono(),
    ),
  );
}
