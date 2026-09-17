import 'package:flutter/material.dart';

import '../session/heel.dart';
import '../theme/deck_theme.dart';

class HeelBanner extends StatelessWidget {
  const HeelBanner({super.key, required this.alert});

  final HeelAlert alert;

  @override
  Widget build(BuildContext context) {
    if (alert == HeelAlert.none) return const SizedBox.shrink();
    final babord = alert == HeelAlert.babord;
    return Container(
      height: 36,
      width: double.infinity,
      color: babord ? DeckColors.babord : DeckColors.tribord,
      alignment: Alignment.center,
      child: Text(
        babord ? 'GÎTE — trop bâbord' : 'GÎTE — trop tribords',
        style: TextStyle(
          color: babord ? Colors.white : const Color(0xFF0B0E12),
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          fontSize: 13,
        ),
      ),
    );
  }
}
