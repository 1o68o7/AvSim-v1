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

/// Signe affiché / jsonl : + = tribords = gauche écran rameur.
/// L’IMU `atan2(ay, az)` est inversé pour ce référentiel.
double rowerGiteFromImu(double imuRollMinusOffset) => -imuRollMinusOffset;

enum HeelAlert { none, tribord, babord }

HeelAlert heelAlertFor(double? giteDeg, {double limitDeg = 3}) {
  if (giteDeg == null) return HeelAlert.none;
  if (giteDeg > limitDeg) return HeelAlert.tribord;
  if (giteDeg < -limitDeg) return HeelAlert.babord;
  return HeelAlert.none;
}

/// +gîte (tribord) → gauche écran (−1) ; −gîte (bâbord) → droite (+1).
double heelAlignmentX(double giteDeg) =>
    (-giteDeg / 15.0).clamp(-1.0, 1.0);

double emaAlphaForTau({required double dtS, required double tauS}) {
  return dtS / (tauS + dtS);
}

double complementaryGyroWeight({required double dtS, required double tauS}) {
  return tauS / (tauS + dtS);
}

double hypot(double a, double b) => sqrt(a * a + b * b);
