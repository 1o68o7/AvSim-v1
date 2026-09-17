import 'package:datar0w/sensors/baro.dart';
import 'package:datar0w/sensors/mag_heading.dart';
import 'package:datar0w/session/model.dart';
import 'package:datar0w/session/tel_cadence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('6 pics stables → SPM, instable → null', () {
    final d = TelCadenceDetector(peakThresh: 1.2);
    final t0 = DateTime.utc(2026, 9, 17);
    // 30 spm = 2.0 s. Impulsion triangulaire toutes les 2 s.
    for (var i = 0; i < 2000; i++) {
      final t = t0.add(Duration(milliseconds: i * 20));
      final phase = (i * 20) % 2000;
      final v = phase < 80 ? 3.0 : 0.0;
      d.add(alongMps2: v, now: t);
    }
    expect(d.spm, isNotNull);
    expect(d.spm!, closeTo(30, 2));

    final bad = TelCadenceDetector(peakThresh: 1.2);
    final periods = [800, 900, 2000, 700, 2100, 800];
    var acc = 0;
    for (final p in periods) {
      acc += p;
      final t = t0.add(Duration(milliseconds: acc));
      bad.add(alongMps2: 3, now: t);
      bad.add(alongMps2: 0, now: t.add(const Duration(milliseconds: 40)));
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
      cadenceSrc: 'tel',
    );
    final line = s.toJsonLine();
    expect(line.contains('"hdg_mag":12.3'), isTrue);
    expect(line.contains('"cadence_src":"tel"'), isTrue);
    final back = SessionSample.fromJson(
      {
        't': 1,
        'dist_m': 0,
        'hdg_mag': 12.3,
        'cadence_src': 'tel',
        'cadence_spm': 28,
      },
    );
    expect(back.hdgMag, 12.3);
    expect(back.cadenceSrc, 'tel');
  });
}
