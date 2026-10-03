import 'dart:convert';
import 'dart:io';

import 'model.dart';
import 'store.dart';
import 'tel_cadence.dart';

/// Recalcule cadence_spm depuis imu.jsonl si les samples n’ont pas encore
/// de cadence IMU. Persistance locale uniquement — pas de re-upload sync.
class CadenceBackfill {
  /// true si des lignes ont été réécrites.
  static Future<bool> maybeBackfill(
    String sessionId, {
    Directory? root,
  }) async {
    final base = root ?? await SessionStore.sessionsRootIfPresent();
    if (base == null) return false;
    final dir = Directory('${base.path}/$sessionId');
    final samplesFile = File('${dir.path}/samples.jsonl');
    final imuFile = File('${dir.path}/imu.jsonl');
    if (!samplesFile.existsSync() || !imuFile.existsSync()) return false;

    final samples = await SessionStore.loadSamples(sessionId, root: base);
    if (samples.isEmpty) return false;

    // Déjà backfillé (source imu_pitch_*) → no-op.
    final hasImuCad = samples.any(
      (s) =>
          s.cadenceSrc == 'imu_pitch_ac' ||
          s.cadenceSrc == 'imu_pitch_ac_approx',
    );
    if (hasImuCad) return false;

    // Seulement si cadence_spm encore null partout (cas GCZEKF).
    final anyCad = samples.any((s) => s.cadenceSpm != null);
    if (anyCad) return false;

    final imu = await loadImuPoints(imuFile);
    if (imu.length < 40) return false;

    final sogSeries = [
      for (final s in samples) SogPoint(tMs: s.t, sog: s.sog),
    ];
    final estimates = TelCadenceDetector.estimateSeries(
      imu: imu,
      sogSeries: sogSeries,
    );
    final patches = TelCadenceDetector.patchSamples1Hz(
      sampleTMs: [for (final s in samples) s.t],
      imuEstimates: estimates,
    );

    final out = <SessionSample>[];
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      final p = patches[i];
      out.add(
        SessionSample(
          t: s.t,
          lat: s.lat,
          lon: s.lon,
          alt: s.alt,
          sog: s.sog,
          cog: s.cog,
          accH: s.accH,
          distM: s.distM,
          giteDeg: s.giteDeg,
          pitchDeg: s.pitchDeg,
          cadenceSpm: p.spm,
          cadenceSrc: p.src,
          hdgMag: s.hdgMag,
          pHpa: s.pHpa,
          altBaro: s.altBaro,
          batt: s.batt,
          net: s.net,
          hrBpm: s.hrBpm,
          spo2Pct: s.spo2Pct,
          hrSource: s.hrSource,
        ),
      );
    }

    final tmp = File('${samplesFile.path}.tmp');
    final sink = tmp.openWrite();
    for (final s in out) {
      sink.writeln(s.toJsonLine());
    }
    await sink.flush();
    await sink.close();
    await tmp.rename(samplesFile.path);
    return true;
  }

  static Future<List<ImuCadencePoint>> loadImuPoints(File imuFile) async {
    final out = <ImuCadencePoint>[];
    if (!imuFile.existsSync()) return out;
    for (final line in await imuFile.readAsLines()) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        final j = jsonDecode(t);
        if (j is! Map) continue;
        final m = Map<String, dynamic>.from(j);
        final ts = (m['t'] as num?)?.toInt();
        final pitch = (m['pitch_raw'] as num?)?.toDouble();
        if (ts == null || pitch == null) continue;
        out.add(
          ImuCadencePoint(
            tMs: ts,
            pitchDeg: pitch,
            gy: (m['gy'] as num?)?.toDouble(),
          ),
        );
      } catch (_) {}
    }
    return out;
  }
}
