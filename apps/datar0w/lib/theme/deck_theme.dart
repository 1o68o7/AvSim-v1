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
  static const Color muted = Color(0xFF8E939D);
}

ThemeData buildDeckTheme() {
  const scheme = ColorScheme.dark(
    surface: DeckColors.bg,
    primary: DeckColors.amber,
    onPrimary: DeckColors.onAlert,
    onSurface: DeckColors.text,
    outline: DeckColors.hairline,
    error: DeckColors.amber,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: DeckColors.bg,
    canvasColor: DeckColors.bg,
    fontFamily: 'monospace',
    appBarTheme: const AppBarTheme(
      backgroundColor: DeckColors.bg,
      foregroundColor: DeckColors.text,
      elevation: 0,
      centerTitle: true,
    ),
    dividerColor: DeckColors.hairline,
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
