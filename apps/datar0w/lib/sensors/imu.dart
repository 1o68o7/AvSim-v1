import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class ImuSample {
  const ImuSample({required this.rollDeg, this.pitchDeg});

  /// Roll brut (pas d’offset tare — lot C).
  final double rollDeg;
  final double? pitchDeg;
}

class ImuService {
  Stream<ImuSample> rollStream() {
    return accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).map((e) {
      final roll = atan2(e.y, e.z) * 180 / pi;
      final pitch = atan2(-e.x, sqrt(e.y * e.y + e.z * e.z)) * 180 / pi;
      return ImuSample(rollDeg: roll, pitchDeg: pitch);
    });
  }
}
