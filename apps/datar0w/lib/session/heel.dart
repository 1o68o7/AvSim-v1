import 'dart:math';

/// Filtre gîte : complémentaire gyro + accéléro, τ ≈ 0,32 s.
/// Le brut IMU ne doit pas pousser l’UI à la cadence capteur.
class HeelFilter {
  HeelFilter({this.tauS = 0.32});

  final double tauS;
  double? filteredDeg;
  double rawAccelRollDeg = 0;
  DateTime? _last;

  double update({
    required double accelRollDeg,
    double gyroDegPerS = 0,
    DateTime? now,
  }) {
    rawAccelRollDeg = accelRollDeg;
    final n = now ?? DateTime.now();
    final dt = _last == null
        ? 0.02
        : (n.difference(_last!).inMicroseconds / 1e6).clamp(0.001, 0.08);
    _last = n;
    if (filteredDeg == null) {
      filteredDeg = accelRollDeg;
      return filteredDeg!;
    }
    final wGyro = tauS / (tauS + dt);
    filteredDeg =
        wGyro * (filteredDeg! + gyroDegPerS * dt) + (1 - wGyro) * accelRollDeg;
    return filteredDeg!;
  }

  void reset() {
    filteredDeg = null;
    rawAccelRollDeg = 0;
    _last = null;
  }
}

double displayDeadband(
  double? previousDisplayed,
  double incoming, {
  double bandDeg = 0.15,
}) {
  if (previousDisplayed == null) return incoming;
  if ((incoming - previousDisplayed).abs() < bandDeg) return previousDisplayed;
  return incoming;
}

double clampHeel(double deg) => deg.clamp(-15.0, 15.0);

/// Normalise 0 / 90 / 180 / 270 (rotation UI depuis le portrait naturel).
int normalizeDisplayRotationDeg(int displayRotationDeg) {
  final r = ((displayRotationDeg % 360) + 360) % 360;
  if (r >= 315 || r < 45) return 0;
  if (r < 135) return 90;
  if (r < 225) return 180;
  return 270;
}

/// Accélération / gyro dans les axes **écran** : +X = droite de l’UI, +Y = haut de l’UI.
({double x, double y, double z}) deviceToScreenVec(
  double x,
  double y,
  double z, {
  required int displayRotationDeg,
}) {
  return switch (normalizeDisplayRotationDeg(displayRotationDeg)) {
    90 => (x: -y, y: x, z: z),
    180 => (x: -x, y: -y, z: z),
    270 => (x: y, y: -x, z: z),
    _ => (x: x, y: y, z: z),
  };
}

/// Gîte rameur (°) depuis l’accéléro, réf. écran.
/// + = TRIBORD = gauche de l’écran en bas (côté haut de l’UI vers la droite).
///
/// Convention accéléro Android au repos : +9,8 du côté « ciel ».
/// Gauche écran en bas ⇒ le vecteur « haut » penche vers la droite ⇒ +screenX.
double screenHeelDeg(
  double ax,
  double ay,
  double az, {
  required int displayRotationDeg,
}) {
  final s = deviceToScreenVec(ax, ay, az, displayRotationDeg: displayRotationDeg);
  return atan2(s.x, hypot(s.y, s.z)) * 180 / pi;
}

/// Vitesse de gîte (°/s) : rotation autour de l’axe sortant de l’écran (Z écran).
/// Signe aligné sur [screenHeelDeg] (gauche en bas → positif).
double screenHeelGyroDegPerS(
  double gx,
  double gy,
  double gz, {
  required int displayRotationDeg,
}) {
  final s = deviceToScreenVec(gx, gy, gz, displayRotationDeg: displayRotationDeg);
  return s.z * 180 / pi;
}

/// [imuRollMinusOffset] est déjà en réf. rameur / écran ([screenHeelDeg]).
double rowerGiteFromImu(double imuRollMinusOffset) => imuRollMinusOffset;

enum HeelAlert { none, tribord, babord }

HeelAlert heelAlertFor(double? giteDeg, {double limitDeg = 3}) {
  if (giteDeg == null) return HeelAlert.none;
  if (giteDeg > limitDeg) return HeelAlert.tribord;
  if (giteDeg < -limitDeg) return HeelAlert.babord;
  return HeelAlert.none;
}

/// +gîte (tribord) → gauche écran rameur (−1) ; −gîte (bâbord) → droite (+1).
/// Barreur : côtés inversés (bâbord à gauche).
double heelAlignmentX(
  double giteDeg, {
  HeelPerspective perspective = HeelPerspective.rower,
}) {
  final x = (-giteDeg / 15.0).clamp(-1.0, 1.0);
  return perspective == HeelPerspective.cox ? -x : x;
}

enum HeelPerspective { rower, cox }

double emaAlphaForTau({required double dtS, required double tauS}) {
  return dtS / (tauS + dtS);
}

double complementaryGyroWeight({required double dtS, required double tauS}) {
  return tauS / (tauS + dtS);
}

double hypot(double a, double b) => sqrt(a * a + b * b);

double hypot3(double a, double b, double c) => sqrt(a * a + b * b + c * c);
