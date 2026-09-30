import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cale-pied : UI paysage, haut du téléphone à gauche de l’écran
/// ([DeviceOrientation.landscapeLeft] = rotation 90°).
/// Gauche écran = TRIBORD, droite = BÂBORD.
Future<void> lockRowerLandscape() {
  return SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
  ]);
}

Future<void> unlockRowerOrientations() {
  return SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

/// 0 = portrait, 90 = paysage (haut appareil à gauche) — axes [screenHeelDeg].
int displayRotationDegOf(BuildContext context) {
  return MediaQuery.orientationOf(context) == Orientation.landscape ? 90 : 0;
}
