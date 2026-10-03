import 'dart:math' as math;

/// Confiance cadence IMU. `low` → jamais affiché comme mesure (`spm` null).
enum CadenceConfidence { high, medium, low }

/// Estimateur live / offline : pitch_raw (secours gy), passe-bande 0,28–0,68 Hz,
/// autocorrélation fenêtre 24 s, recoupement pics.
///
/// Sources JSONL :
/// - high → `imu_pitch_ac`
/// - medium → `imu_pitch_ac_approx`
/// - low → `cadence_spm` null, `cadence_src` null
class TelCadenceDetector {
  TelCadenceDetector({
    this.windowS = 24.0,
    this.minLagS = 1.45,
    this.maxLagS = 3.8,
    this.hpHz = 0.28,
    this.lpHz = 0.68,
    this.minPeakGapS = 1.5,
    this.highForce = 0.35,
    this.mediumForce = 0.22,
    this.highSog = 1.6,
    this.mediumSog = 1.1,
    this.maxSpmDelta = 5.0,
  });

  final double windowS;
  final double minLagS;
  final double maxLagS;
  final double hpHz;
  final double lpHz;
  final double minPeakGapS;
  final double highForce;
  final double mediumForce;
  final double highSog;
  final double mediumSog;
  final double maxSpmDelta;

  /// Coups/min affichables. Null si [confidence] == low.
  double? spm;

  CadenceConfidence confidence = CadenceConfidence.low;

  /// `imu_pitch_ac` | `imu_pitch_ac_approx` | null
  String? src;

  double? _sog;
  final List<CadenceBufSample> _buf = [];

  // Filtres 1er ordre (état).
  double _hpY = 0;
  double _hpX = 0;
  double _lpY = 0;
  bool _filtInit = false;
  double _lastTs = 0;

  void reset() {
    spm = null;
    confidence = CadenceConfidence.low;
    src = null;
    _sog = null;
    _buf.clear();
    _hpY = 0;
    _hpX = 0;
    _lpY = 0;
    _filtInit = false;
    _lastTs = 0;
  }

  void setSog(double? sogMps) => _sog = sogMps;

  /// API live : pitch (deg) prioritaire, gy (deg/s) en secours si pitch plat.
  void add({
    required double pitchDeg,
    double? gy,
    required DateTime now,
    double? sog,
  }) {
    if (sog != null) _sog = sog;
    final t = now.millisecondsSinceEpoch / 1000.0;
    var signal = pitchDeg;
    // Secours gy si le pitch est quasi constant dans le buffer récent.
    if (_buf.length >= 8 && gy != null) {
      var minP = _buf.last.raw;
      var maxP = _buf.last.raw;
      final n = math.min(16, _buf.length);
      for (var i = _buf.length - n; i < _buf.length; i++) {
        final v = _buf[i].raw;
        if (v < minP) minP = v;
        if (v > maxP) maxP = v;
      }
      if ((maxP - minP).abs() < 0.4) {
        signal = gy;
      }
    }

    final filtered = _bandpass(signal, t);
    _buf.add(CadenceBufSample(t: t, raw: pitchDeg, y: filtered));
    final cut = t - windowS;
    while (_buf.isNotEmpty && _buf.first.t < cut) {
      _buf.removeAt(0);
    }
    _recompute();
  }

  /// Compat tests / anciens call sites accélération — traité comme signal brut.
  @Deprecated('Utiliser add(pitchDeg:, gy:, now:, sog:)')
  void addAlong({required double alongMps2, required DateTime now}) {
    add(pitchDeg: alongMps2 * 8, now: now, sog: 3.0);
  }

  double _bandpass(double x, double t) {
    if (!_filtInit) {
      _filtInit = true;
      _hpX = x;
      _hpY = 0;
      _lpY = 0;
      _lastTs = t;
      return 0;
    }
    var dt = t - _lastTs;
    _lastTs = t;
    if (dt <= 0 || dt > 1.0) dt = 1.0 / 17.5;

    // HP 1er ordre @ hpHz
    final rcHp = 1.0 / (2 * math.pi * hpHz);
    final aHp = rcHp / (rcHp + dt);
    final hp = aHp * (_hpY + x - _hpX);
    _hpX = x;
    _hpY = hp;

    // LP 1er ordre @ lpHz
    final rcLp = 1.0 / (2 * math.pi * lpHz);
    final aLp = dt / (rcLp + dt);
    _lpY = _lpY + aLp * (hp - _lpY);
    return _lpY;
  }

  void _recompute() {
    final est = estimateWindow(
      samples: _buf,
      sog: _sog,
      minLagS: minLagS,
      maxLagS: maxLagS,
      minPeakGapS: minPeakGapS,
      highForce: highForce,
      mediumForce: mediumForce,
      highSog: highSog,
      mediumSog: mediumSog,
      maxSpmDelta: maxSpmDelta,
    );
    spm = est.spm;
    confidence = est.confidence;
    src = est.src;
  }

  /// Estimateur pur (tests + backfill offline).
  static CadenceEstimate estimateWindow({
    required List<CadenceBufSample> samples,
    double? sog,
    double minLagS = 1.45,
    double maxLagS = 3.8,
    double minPeakGapS = 1.5,
    double highForce = 0.35,
    double mediumForce = 0.22,
    double highSog = 1.6,
    double mediumSog = 1.1,
    double maxSpmDelta = 5.0,
  }) {
    const low = CadenceEstimate(
      spm: null,
      confidence: CadenceConfidence.low,
      src: null,
    );
    if (samples.length < 40) return low;

    final t0 = samples.first.t;
    final t1 = samples.last.t;
    final dur = t1 - t0;
    if (dur < 8.0) return low;

    final fs = (samples.length - 1) / dur;
    if (fs < 5 || fs > 80) return low;

    final ys = [for (final s in samples) s.y];
    // Demean
    var mean = 0.0;
    for (final y in ys) {
      mean += y;
    }
    mean /= ys.length;
    final x = [for (final y in ys) y - mean];

    final minLag = math.max(1, (minLagS * fs).floor());
    final maxLag = math.min(x.length ~/ 2, (maxLagS * fs).ceil());
    if (maxLag <= minLag) return low;

    var energy = 0.0;
    for (final v in x) {
      energy += v * v;
    }
    if (energy < 1e-9) return low;

    var bestLag = minLag;
    var bestAc = -1.0;
    for (var lag = minLag; lag <= maxLag; lag++) {
      var num = 0.0;
      final n = x.length - lag;
      for (var i = 0; i < n; i++) {
        num += x[i] * x[i + lag];
      }
      final ac = num / energy;
      if (ac > bestAc) {
        bestAc = ac;
        bestLag = lag;
      }
    }
    final force = bestAc;
    final periodAc = bestLag / fs;
    final spmAc = 60.0 / periodAc;

    final spmPeaks = _spmFromPeaks(
      times: [for (final s in samples) s.t],
      signal: x,
      minGapS: minPeakGapS,
    );

    return classify(
      force: force,
      sog: sog ?? 0.0,
      spmAc: spmAc,
      spmPeaks: spmPeaks,
      highForce: highForce,
      mediumForce: mediumForce,
      highSog: highSog,
      mediumSog: mediumSog,
      maxSpmDelta: maxSpmDelta,
    );
  }

  /// Décision high / medium / low (testable sans signal).
  /// high exige un recoupement pics (`spmPeaks != null`) — pas de high
  /// si seuls force + sog sont bons.
  static CadenceEstimate classify({
    required double force,
    required double sog,
    required double spmAc,
    double? spmPeaks,
    double highForce = 0.35,
    double mediumForce = 0.22,
    double highSog = 1.6,
    double mediumSog = 1.1,
    double maxSpmDelta = 5.0,
  }) {
    final peaksOk =
        spmPeaks != null && (spmAc - spmPeaks).abs() < maxSpmDelta;
    if (force >= highForce && sog >= highSog && peaksOk) {
      return CadenceEstimate(
        spm: spmAc,
        confidence: CadenceConfidence.high,
        src: 'imu_pitch_ac',
        force: force,
        spmAc: spmAc,
        spmPeaks: spmPeaks,
      );
    }
    // Pics absents ou divergents : medium si force/sog suffisent.
    if (force >= mediumForce && sog >= mediumSog) {
      return CadenceEstimate(
        spm: spmAc,
        confidence: CadenceConfidence.medium,
        src: 'imu_pitch_ac_approx',
        force: force,
        spmAc: spmAc,
        spmPeaks: spmPeaks,
      );
    }
    return CadenceEstimate(
      spm: null,
      confidence: CadenceConfidence.low,
      src: null,
      force: force,
      spmAc: spmAc,
      spmPeaks: spmPeaks,
    );
  }

  static double? _spmFromPeaks({
    required List<double> times,
    required List<double> signal,
    required double minGapS,
  }) {
    if (signal.length < 8) return null;
    var mean = 0.0;
    var m2 = 0.0;
    for (final v in signal) {
      mean += v;
    }
    mean /= signal.length;
    for (final v in signal) {
      final d = v - mean;
      m2 += d * d;
    }
    final sigma = math.sqrt(m2 / signal.length);
    final thr = math.max(0.35, 0.55 * sigma);

    final peakTimes = <double>[];
    for (var i = 1; i < signal.length - 1; i++) {
      final y = signal[i];
      if (y < thr) continue;
      if (y >= signal[i - 1] && y > signal[i + 1]) {
        final t = times[i];
        if (peakTimes.isEmpty || t - peakTimes.last >= minGapS) {
          peakTimes.add(t);
        } else if (y > signal[_indexNear(times, peakTimes.last)]) {
          peakTimes[peakTimes.length - 1] = t;
        }
      }
    }
    if (peakTimes.length < 3) return null;
    final gaps = <double>[];
    for (var i = 1; i < peakTimes.length; i++) {
      gaps.add(peakTimes[i] - peakTimes[i - 1]);
    }
    gaps.sort();
    final med = gaps[gaps.length ~/ 2];
    if (med <= 0) return null;
    return 60.0 / med;
  }

  static int _indexNear(List<double> times, double t) {
    var best = 0;
    var bestD = (times[0] - t).abs();
    for (var i = 1; i < times.length; i++) {
      final d = (times[i] - t).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  /// Recalcule une série 1 Hz à partir d'imu.jsonl + sog samples.
  static List<CadenceEstimate> estimateSeries({
    required List<ImuCadencePoint> imu,
    required List<SogPoint> sogSeries,
    double windowS = 24.0,
  }) {
    if (imu.isEmpty) return const [];
    final out = <CadenceEstimate>[];
    // Préfiltre offline (même bande) en une passe.
    final det = TelCadenceDetector(windowS: windowS);
    var sogIdx = 0;
    double? sog;
    for (final p in imu) {
      while (sogIdx < sogSeries.length &&
          sogSeries[sogIdx].tMs <= p.tMs) {
        sog = sogSeries[sogIdx].sog;
        sogIdx++;
      }
      det.add(
        pitchDeg: p.pitchDeg,
        gy: p.gy,
        now: DateTime.fromMillisecondsSinceEpoch(p.tMs, isUtc: true),
        sog: sog,
      );
      out.add(
        CadenceEstimate(
          spm: det.spm,
          confidence: det.confidence,
          src: det.src,
          tMs: p.tMs,
        ),
      );
    }
    return out;
  }

  /// Pour chaque sample 1 Hz, prend l’estimée IMU la plus récente ≤ t.
  static List<SessionCadencePatch> patchSamples1Hz({
    required List<int> sampleTMs,
    required List<CadenceEstimate> imuEstimates,
  }) {
    final out = <SessionCadencePatch>[];
    var j = 0;
    CadenceEstimate? last;
    for (final t in sampleTMs) {
      while (j < imuEstimates.length && (imuEstimates[j].tMs ?? 0) <= t) {
        last = imuEstimates[j];
        j++;
      }
      out.add(
        SessionCadencePatch(
          tMs: t,
          spm: last?.spm,
          src: last?.src,
          confidence: last?.confidence ?? CadenceConfidence.low,
        ),
      );
    }
    return out;
  }
}

class CadenceEstimate {
  const CadenceEstimate({
    required this.spm,
    required this.confidence,
    required this.src,
    this.force,
    this.spmAc,
    this.spmPeaks,
    this.tMs,
  });

  final double? spm;
  final CadenceConfidence confidence;
  final String? src;
  final double? force;
  final double? spmAc;
  final double? spmPeaks;
  final int? tMs;
}

class SessionCadencePatch {
  const SessionCadencePatch({
    required this.tMs,
    required this.spm,
    required this.src,
    required this.confidence,
  });

  final int tMs;
  final double? spm;
  final String? src;
  final CadenceConfidence confidence;
}

class ImuCadencePoint {
  const ImuCadencePoint({
    required this.tMs,
    required this.pitchDeg,
    this.gy,
  });

  final int tMs;
  final double pitchDeg;
  final double? gy;
}

class SogPoint {
  const SogPoint({required this.tMs, this.sog});
  final int tMs;
  final double? sog;
}

class CadenceBufSample {
  const CadenceBufSample({
    required this.t,
    required this.raw,
    required this.y,
  });
  final double t;
  final double raw;
  final double y;
}

/// Stats séance pour summary / export. Nulls ignorés (jamais moyennés comme 0).
class SessionCadenceStats {
  const SessionCadenceStats({
    this.meanNonNull,
    this.medianHigh,
    this.fracHigh = 0,
    this.fracMedium = 0,
    this.fracLow = 1,
    this.nHigh = 0,
    this.nMedium = 0,
    this.nLow = 0,
  });

  final double? meanNonNull;
  final double? medianHigh;
  final double fracHigh;
  final double fracMedium;
  final double fracLow;
  final int nHigh;
  final int nMedium;
  final int nLow;

  static SessionCadenceStats fromSamples(
    Iterable<({double? spm, String? src})> rows,
  ) {
    final nonNull = <double>[];
    final highs = <double>[];
    var nH = 0, nM = 0, nL = 0;
    var n = 0;
    for (final r in rows) {
      n++;
      final src = r.src;
      final spm = r.spm;
      if (src == 'imu_pitch_ac' && spm != null) {
        nH++;
        highs.add(spm);
        nonNull.add(spm);
      } else if (src == 'imu_pitch_ac_approx' && spm != null) {
        nM++;
        nonNull.add(spm);
      } else if (spm != null && src == 'tel') {
        // Ancien détecteur : compter medium-ish, pas high.
        nM++;
        nonNull.add(spm);
      } else {
        nL++;
      }
    }
    if (n == 0) return const SessionCadenceStats();
    double? mean;
    if (nonNull.isNotEmpty) {
      var s = 0.0;
      for (final v in nonNull) {
        s += v;
      }
      mean = s / nonNull.length;
    }
    double? medH;
    if (highs.isNotEmpty) {
      final sorted = [...highs]..sort();
      medH = sorted[sorted.length ~/ 2];
    }
    return SessionCadenceStats(
      meanNonNull: mean,
      medianHigh: medH,
      fracHigh: nH / n,
      fracMedium: nM / n,
      fracLow: nL / n,
      nHigh: nH,
      nMedium: nM,
      nLow: nL,
    );
  }
}

/// Affichage UI : high = chiffre ; medium = ~ + approximatif ; low = —.
String formatCadenceValue(double? spm, String? src) {
  if (spm == null || src == null) return '—';
  final n = spm.round().toString();
  if (src == 'imu_pitch_ac_approx') return '~$n';
  return n;
}

String? cadenceApproxLabel(String? src) {
  if (src == 'imu_pitch_ac_approx') return 'approximatif';
  return null;
}

bool cadenceIsDisplayable(String? src, double? spm) =>
    spm != null && src != null;

/// Liste / home / club : médiane high sec ; part medium à côté ;
/// moyenne seule → `~` ; low seul → `—` (jamais 0).
String formatSessionCadenceSummary({
  double? medianHigh,
  double? meanNonNull,
  double fracMedium = 0,
}) {
  if (medianHigh != null) {
    final n = medianHigh.round().toString();
    if (fracMedium > 0) {
      final pct = (fracMedium * 100).round();
      return '$n · $pct % approximatif';
    }
    return n;
  }
  if (meanNonNull != null) {
    return '~${meanNonNull.round()}';
  }
  return '—';
}

String formatSessionCadenceFromSummary(SessionCadenceStats stats) =>
    formatSessionCadenceSummary(
      medianHigh: stats.medianHigh,
      meanNonNull: stats.meanNonNull,
      fracMedium: stats.fracMedium,
    );
