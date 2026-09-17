import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class ImuFrame {
  const ImuFrame({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.accelRollDeg,
    required this.accelPitchDeg,
  });

  final double ax;
  final double ay;
  final double az;
  final double gx;
  final double gy;
  final double gz;
  final double accelRollDeg;
  final double accelPitchDeg;
}

class ImuService {
  double _gx = 0;
  double _gy = 0;
  double _gz = 0;

  /// Accéléro + dernier gyro. Le hub filtre ; pas d’UI ici.
  Stream<ImuFrame> frameStream() async* {
    gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (g) {
        _gx = g.x;
        _gy = g.y;
        _gz = g.z;
      },
      onError: (_) {},
    );
    await for (final e in accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    )) {
      final roll = atan2(e.y, e.z) * 180 / pi;
      final pitch = atan2(-e.x, sqrt(e.y * e.y + e.z * e.z)) * 180 / pi;
      yield ImuFrame(
        ax: e.x,
        ay: e.y,
        az: e.z,
        gx: _gx,
        gy: _gy,
        gz: _gz,
        accelRollDeg: roll,
        accelPitchDeg: pitch,
      );
    }
  }
}
