import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/deck_theme.dart';

const String kStopArmedMessage = 'Encore une fois pour arrêter';

void hapticStopArmed() {
  HapticFeedback.mediumImpact();
}

/// Bandeau STOP armé — overlay, ne pousse pas les 3 colonnes.
class StopArmedBanner extends StatelessWidget {
  const StopArmedBanner({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: ColoredBox(
          color: DeckColors.amber.withValues(alpha: 0.92),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              kStopArmedMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DeckColors.onAlert,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Commande Layout visible (icône + texte, hit ≥ 48).
class LiveLayoutButton extends StatelessWidget {
  const LiveLayoutButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Layout',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: const SizedBox(
            width: 72,
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grid_view, size: 18, color: DeckColors.amber),
                SizedBox(height: 2),
                Text(
                  'Layout',
                  style: TextStyle(
                    color: DeckColors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
