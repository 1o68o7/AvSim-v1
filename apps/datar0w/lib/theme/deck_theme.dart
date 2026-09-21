import 'package:flutter/material.dart';

/// Marine Avionics Deck — `docs/stitch-mvp/GEL.md`.
/// Alerte gîte (écran 4) = [alert], jamais cyan High-Vis `#00E676`.
abstract final class DeckColors {
  static const Color bg = Color(0xFF0B0E12);
  static const Color surface = Color(0xFF111418);
  static const Color surfaceHigh = Color(0xFF1D2024);
  static const Color hairline = Color(0xFF2A2F36);
  static const Color label = Color(0xFF9AA0A6);
  static const Color text = Color(0xFFFFFFFF);
  static const Color amber = Color(0xFFE8C547);
  static const Color alert = Color(0xFFE8C547);
  static const Color onAlert = Color(0xFF0B0E12);
  /// Erreur bloquante — distincte de l’ambre CTA / alerte gîte.
  static const Color error = Color(0xFFE05353);
  static const Color babord = Color(0xFFE05353);
  static const Color tribord = Color(0xFF46C275);
  /// Bandeau alerte « trop tribords » — vert foncé (libellés restent [tribord]).
  static const Color tribordAlert = Color(0xFF0F5C32);
  static const Color muted = Color(0xFF8E939D);
}

ThemeData buildDeckTheme() {
  const scheme = ColorScheme.dark(
    surface: DeckColors.bg,
    primary: DeckColors.amber,
    onPrimary: DeckColors.onAlert,
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
    fontFamily: 'JetBrainsMono',
    appBarTheme: const AppBarTheme(
      backgroundColor: DeckColors.bg,
      foregroundColor: DeckColors.text,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
    ),
    dividerColor: DeckColors.hairline,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: DeckColors.amber,
        foregroundColor: DeckColors.onAlert,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          fontFamily: 'JetBrainsMono',
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: DeckColors.label,
        side: const BorderSide(color: DeckColors.hairline),
        shape: const RoundedRectangleBorder(),
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          fontFamily: 'JetBrainsMono',
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: DeckColors.label,
        shape: const RoundedRectangleBorder(),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: DeckColors.bg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: DeckColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: DeckColors.amber),
      ),
      labelStyle: TextStyle(color: DeckColors.label, letterSpacing: 1.2),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: DeckColors.text,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      bodyMedium: TextStyle(color: DeckColors.text),
      labelSmall: TextStyle(
        color: DeckColors.label,
        letterSpacing: 1.2,
      ),
    ),
  );
}
