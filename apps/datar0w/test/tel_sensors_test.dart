import 'dart:math' as math;

import 'package:datar0w/sensors/baro.dart';
import 'package:datar0w/sensors/mag_heading.dart';
import 'package:datar0w/session/model.dart';
import 'package:datar0w/session/tel_cadence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pitch stable 30 spm → SPM high ; sog bas → null', () {
    final d = TelCadenceDetector();
    final t0 = DateTime.utc(2026, 9, 17);
    // 30 spm = 2.0 s, ~17.5 Hz, 28 s, sog OK.
    for (var i = 0; i < 500; i++) {
      final t = t0.add(Duration(milliseconds: (i * 1000 / 17.5).round()));
      final pitch = 4.0 * math.sin(2 * math.pi * (i / 17.5) / 2.0);
      d.add(pitchDeg: pitch, now: t, sog: 2.5);
    }
    expect(d.spm, isNotNull);
    expect(d.spm!, closeTo(30, 2));
    expect(d.src, 'imu_pitch_ac');

    final bad = TelCadenceDetector();
    for (var i = 0; i < 500; i++) {
      final t = t0.add(Duration(milliseconds: (i * 1000 / 17.5).round()));
      final pitch = 4.0 * math.sin(2 * math.pi * (i / 17.5) / 2.0);
      bad.add(pitchDeg: pitch, now: t, sog: 0.3);
    }
    expect(bad.spm, isNull);
  });

  test('cap magnéto 0–360, pas NaN', () {
    final h = magHeadingDeg(
      mx: 20,
      my: 0,
      mz: 0,
      ax: 0,
      ay: 0,
      az: 9.8,
    );
    expect(h, isNotNull);
    expect(h! >= 0 && h < 360, isTrue);
  });

  test('baro relative : même P → 0 m', () {
    expect(altBaroRelM(1013.25, 1013.25), closeTo(0, 0.05));
    expect(altBaroRelM(null, 1013), isNull);
    expect(altBaroRelM(1013, null), isNull);
    expect(altBaroRelM(0, 1013), isNull);
  });

  test('jsonl P1 clés optionnelles', () {
    const s = SessionSample(
      t: 1,
      distM: 0,
      net: 'wifi',
      hdgMag: 12.3,
      pHpa: 1012,
      altBaro: 1.2,
      cadenceSpm: 28,
      cadenceSrc: 'imu_pitch_ac',
    );
    final line = s.toJsonLine();
    expect(line.contains('"hdg_mag":12.3'), isTrue);
    expect(line.contains('"cadence_src":"imu_pitch_ac"'), isTrue);
    final back = SessionSample.fromJson(
      {
        't': 1,
        'dist_m': 0,
        'hdg_mag': 12.3,
        'cadence_src': 'imu_pitch_ac',
        'cadence_spm': 28,
      },
    );
    expect(back.hdgMag, 12.3);
    expect(back.cadenceSrc, 'imu_pitch_ac');
  });
}
