import 'package:flutter/material.dart';

import '../session/heel.dart';
import '../theme/deck_theme.dart';

class HeelBanner extends StatelessWidget {
  const HeelBanner({super.key, required this.alert});

  final HeelAlert alert;

  static Color backgroundFor(HeelAlert alert) => switch (alert) {
        HeelAlert.babord => DeckColors.babord,
        HeelAlert.tribord => DeckColors.tribordAlert,
        HeelAlert.none => Colors.transparent,
      };

  static Color foregroundFor(HeelAlert alert) => Colors.white;

  @override
  Widget build(BuildContext context) {
    if (alert == HeelAlert.none) return const SizedBox.shrink();
    final babord = alert == HeelAlert.babord;
    return Container(
      height: 36,
      width: double.infinity,
      color: backgroundFor(alert),
      alignment: Alignment.center,
      child: Text(
        babord ? 'GÎTE — trop bâbord' : 'GÎTE — trop tribords',
        style: TextStyle(
          color: foregroundFor(alert),
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          fontSize: 13,
        ),
      ),
    );
  }
}
