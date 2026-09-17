import 'dart:async';
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

  /// Accéléro (gravité incluse = niveau du téléphone) + dernier gyro.
  Stream<ImuFrame> frameStream() {
    late StreamController<ImuFrame> controller;
    StreamSubscription<GyroscopeEvent>? gyroSub;
    StreamSubscription<AccelerometerEvent>? accelSub;
    var usingFallback = false;

    void attachAccel(Duration period) {
      accelSub?.cancel();
      accelSub = accelerometerEventStream(samplingPeriod: period).listen(
        (e) {
          final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
          if (mag < 1e-3) return;
          final roll = atan2(e.y, e.z) * 180 / pi;
          final pitch = atan2(-e.x, sqrt(e.y * e.y + e.z * e.z)) * 180 / pi;
          if (!controller.isClosed) {
            controller.add(
              ImuFrame(
                ax: e.x,
                ay: e.y,
                az: e.z,
                gx: _gx,
                gy: _gy,
                gz: _gz,
                accelRollDeg: roll,
                accelPitchDeg: pitch,
              ),
            );
          }
        },
        onError: (Object e, StackTrace st) {
          if (!usingFallback) {
            usingFallback = true;
            attachAccel(SensorInterval.normalInterval);
            return;
          }
          if (!controller.isClosed) controller.addError(e, st);
        },
      );
    }

    controller = StreamController<ImuFrame>(
      onListen: () {
        gyroSub = gyroscopeEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen(
          (g) {
            _gx = g.x;
            _gy = g.y;
            _gz = g.z;
          },
          onError: (_) {},
        );
        attachAccel(SensorInterval.uiInterval);
      },
      onCancel: () async {
        await gyroSub?.cancel();
        await accelSub?.cancel();
      },
    );
    return controller.stream;
  }
}
