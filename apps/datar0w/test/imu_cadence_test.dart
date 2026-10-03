import 'dart:io';
import 'dart:math' as math;

import 'package:datar0w/funnel/logbook_export.dart';
import 'package:datar0w/session/cadence_backfill.dart';
import 'package:datar0w/session/model.dart';
import 'package:datar0w/session/store.dart';
import 'package:datar0w/session/summary.dart';
import 'package:datar0w/session/tel_cadence.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sinus pitch période [periodS], ~17.5 Hz, durée [durationS].
void _feedSinus(
  TelCadenceDetector d, {
  required double periodS,
  required double sog,
  double durationS = 28,
  double ampDeg = 4.0,
  double fs = 17.5,
}) {
  final t0 = DateTime.utc(2026, 10, 3, 12);
  final n = (durationS * fs).round();
  for (var i = 0; i < n; i++) {
    final t = t0.add(Duration(milliseconds: (i * 1000 / fs).round()));
    final pitch = ampDeg * math.sin(2 * math.pi * (i / fs) / periodS);
    d.add(pitchDeg: pitch, gy: 0, now: t, sog: sog);
  }
}

void main() {
  test('sinus pitch 2,05 s + sog 3 → high, spm ±1 de 29,3', () {
    final d = TelCadenceDetector();
    _feedSinus(d, periodS: 2.05, sog: 3.0);
    expect(d.confidence, CadenceConfidence.high);
    expect(d.spm, isNotNull);
    expect(d.spm!, closeTo(60 / 2.05, 1.0));
    expect(d.src, 'imu_pitch_ac');
  });

  test('même signal + sog 0,4 → low, spm null', () {
    final d = TelCadenceDetector();
    _feedSinus(d, periodS: 2.05, sog: 0.4);
    expect(d.confidence, CadenceConfidence.low);
    expect(d.spm, isNull);
    expect(d.src, isNull);
  });

  test('deux estimateurs divergents de > 5 spm → pas high', () {
    final est = TelCadenceDetector.classify(
      force: 0.5,
      sog: 3.0,
      spmAc: 30,
      spmPeaks: 22, // |30-22|=8 > 5
    );
    expect(est.confidence, isNot(CadenceConfidence.high));
    // force + sog suffisent pour medium
    expect(est.confidence, CadenceConfidence.medium);
    expect(est.spm, isNotNull);
    expect(est.src, 'imu_pitch_ac_approx');
  });

  test('GCZEKF-like fixture : médiane high dans 28–31', () {
    // Extrait synthétique calé sur la référence GCZEKF (~29,2 médiane high).
    final d = TelCadenceDetector();
    _feedSinus(d, periodS: 60 / 29.2, sog: 2.8, durationS: 40, ampDeg: 5);
    expect(d.confidence, CadenceConfidence.high);
    expect(d.spm!, inInclusiveRange(28.0, 31.0));

    // Série 1 Hz patchée : majorité high autour de 29.
    final imu = <ImuCadencePoint>[];
    final t0 = 1_700_000_000_000;
    const fs = 17.5;
    const period = 60 / 29.2;
    for (var i = 0; i < (40 * fs).round(); i++) {
      final tMs = t0 + (i * 1000 / fs).round();
      final pitch = 5.0 * math.sin(2 * math.pi * (i / fs) / period);
      imu.add(ImuCadencePoint(tMs: tMs, pitchDeg: pitch, gy: 0));
    }
    final sog = [
      for (var s = 0; s < 40; s++)
        SogPoint(tMs: t0 + s * 1000, sog: 2.8),
    ];
    final est = TelCadenceDetector.estimateSeries(imu: imu, sogSeries: sog);
    final highs = [
      for (final e in est)
        if (e.confidence == CadenceConfidence.high && e.spm != null) e.spm!,
    ];
    expect(highs.length, greaterThan(10));
    highs.sort();
    final med = highs[highs.length ~/ 2];
    expect(med, inInclusiveRange(28.0, 31.0));
  });

  test('SessionSummary ignore les null (pas de moyenne à 0)', () {
    final samples = [
      const SessionSample(
        t: 1000,
        distM: 10,
        net: 'wifi',
        cadenceSpm: 30,
        cadenceSrc: 'imu_pitch_ac',
      ),
      const SessionSample(
        t: 2000,
        distM: 20,
        net: 'wifi',
        // low → null
      ),
      const SessionSample(
        t: 3000,
        distM: 30,
        net: 'wifi',
        cadenceSpm: 28,
        cadenceSrc: 'imu_pitch_ac',
      ),
      const SessionSample(
        t: 4000,
        distM: 40,
        net: 'wifi',
        cadenceSpm: 29,
        cadenceSrc: 'imu_pitch_ac_approx',
      ),
    ];
    final s = SessionSummary.fromSamples(samples);
    // (30+28+29)/3 — le null n’entre pas
    // (30+28+29)/3 — le null n’entre pas
    expect(s.cadenceMean, closeTo(29.0, 0.01));
    // high = [30, 28] → médiane index length~/2 = 30
    expect(s.cadenceMedianHigh, closeTo(30.0, 0.01));
    expect(s.cadenceFracLow, closeTo(0.25, 1e-9));
    expect(s.cadenceFracHigh, closeTo(0.5, 1e-9));
    expect(s.cadenceFracMedium, closeTo(0.25, 1e-9));
  });

  test('formatCadenceValue : high / ~medium / — low', () {
    expect(formatCadenceValue(29.2, 'imu_pitch_ac'), '29');
    expect(formatCadenceValue(28.4, 'imu_pitch_ac_approx'), '~28');
    expect(formatCadenceValue(30, null), '—');
    expect(formatCadenceValue(null, 'imu_pitch_ac'), '—');
    expect(cadenceApproxLabel('imu_pitch_ac_approx'), 'approximatif');
    expect(cadenceApproxLabel('imu_pitch_ac'), isNull);
  });

  test('backfill écrit imu_pitch_ac dans samples.jsonl', () async {
    final root = Directory.systemTemp.createTempSync('cad_bf_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final dir = Directory('${root.path}/GCZEKF')..createSync();
    final imu = File('${dir.path}/imu.jsonl');
    final samples = File('${dir.path}/samples.jsonl');
    final t0 = 1_700_000_000_000;
    const fs = 17.5;
    const period = 2.05;
    final buf = StringBuffer();
    for (var i = 0; i < (30 * fs).round(); i++) {
      final tMs = t0 + (i * 1000 / fs).round();
      final pitch = 4.0 * math.sin(2 * math.pi * (i / fs) / period);
      buf.writeln(
        '{"t":$tMs,"ax":0,"ay":0,"az":9.8,"gx":0,"gy":0,"gz":0,'
        '"roll_raw":0,"pitch_raw":$pitch}',
      );
    }
    await imu.writeAsString(buf.toString());
    final sbuf = StringBuffer();
    for (var s = 0; s < 30; s++) {
      final tMs = t0 + s * 1000;
      sbuf.writeln(
        '{"t":$tMs,"lat":44.8,"lon":-0.5,"sog":2.8,"dist_m":${s * 3},'
        '"net":"wifi","cadence_spm":null,"cadence_src":null}',
      );
    }
    await samples.writeAsString(sbuf.toString());
    await File('${dir.path}/meta.json').writeAsString(
      '{"id":"GCZEKF","class":"1x","started_at":"2026-10-03T12:00:00Z"}',
    );

    final ok = await CadenceBackfill.maybeBackfill('GCZEKF', root: root);
    expect(ok, isTrue);
    final loaded = await SessionStore.loadSamples('GCZEKF', root: root);
    final withCad = loaded.where((s) => s.cadenceSpm != null).toList();
    expect(withCad, isNotEmpty);
    expect(
      withCad.any((s) => s.cadenceSrc == 'imu_pitch_ac'),
      isTrue,
    );
    // Second passage : no-op
    expect(await CadenceBackfill.maybeBackfill('GCZEKF', root: root), isFalse);
  });

  test('logbook cadence stats inclut médiane high et part approx', () {
    final summary = SessionSummary.fromSamples([
      const SessionSample(
        t: 1,
        distM: 1,
        net: 'x',
        cadenceSpm: 29.2,
        cadenceSrc: 'imu_pitch_ac',
      ),
      const SessionSample(
        t: 2,
        distM: 2,
        net: 'x',
        cadenceSpm: 28.5,
        cadenceSrc: 'imu_pitch_ac_approx',
      ),
      const SessionSample(t: 3, distM: 3, net: 'x'),
    ]);
    final csv = LogbookExport.cadenceStatsCsv(summary);
    expect(csv, contains('cadence_median_high_spm'));
    expect(csv, contains('frac_approx'));
    expect(csv, contains('29.20'));
    final json = LogbookExport.cadenceStatsJson(summary);
    expect(json['cadence_median_high_spm'], closeTo(29.2, 0.01));
    expect(json['frac_approx'], closeTo(1 / 3, 1e-9));
  });
}
