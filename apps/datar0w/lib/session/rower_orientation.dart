import 'dart:async';

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

/// Hubs `/identity`, `/auth`, `/home/*` — portrait only (hotfix OnePlus).
Future<void> lockPortraitHub() {
  return SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
}

Future<void> unlockRowerOrientations() {
  return SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

/// Pose le lock portrait une fois à l’entrée de l’écran.
class PortraitLockScope extends StatefulWidget {
  const PortraitLockScope({super.key, required this.child});

  final Widget child;

  @override
  State<PortraitLockScope> createState() => _PortraitLockScopeState();
}

class _PortraitLockScopeState extends State<PortraitLockScope> {
  @override
  void initState() {
    super.initState();
    unawaited(lockPortraitHub());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 0 = portrait, 90 = paysage (haut appareil à gauche) — axes [screenHeelDeg].
int displayRotationDegOf(BuildContext context) {
  return MediaQuery.orientationOf(context) == Orientation.landscape ? 90 : 0;
}
