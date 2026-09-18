import 'dart:math';

class TareResult {
  const TareResult({
    required this.offsetDeg,
    required this.sigmaDeg,
    required this.ok,
  });

  final double offsetDeg;
  final double sigmaDeg;
  final bool ok;
}

class TareSample {
  const TareSample({required this.t, required this.rollDeg});

  final DateTime t;
  final double rollDeg;
}

class AdaptiveTareEval {
  const AdaptiveTareEval({
    required this.complete,
    required this.ok,
    required this.approx,
    required this.offsetDeg,
    required this.sigmaDeg,
    required this.durationS,
  });

  final bool complete;
  final bool ok;
  final bool approx;
  final double offsetDeg;
  final double sigmaDeg;
  final double durationS;

  String get quality => ok ? 'ok' : (approx ? 'approx' : 'none');
}

/// Offset = moyenne ; OK si σ < [maxSigmaDeg] (brief 0,2°).
TareResult computeTare(List<double> filteredRolls, {double maxSigmaDeg = 0.2}) {
  if (filteredRolls.length < 10) {
    return const TareResult(offsetDeg: 0, sigmaDeg: double.infinity, ok: false);
  }
  final n = filteredRolls.length;
  var sum = 0.0;
  for (final v in filteredRolls) {
    sum += v;
  }
  final mean = sum / n;
  var acc = 0.0;
  for (final v in filteredRolls) {
    final d = v - mean;
    acc += d * d;
  }
  final sigma = sqrt(acc / n);
  return TareResult(
    offsetDeg: mean,
    sigmaDeg: sigma,
    ok: sigma < maxSigmaDeg,
  );
}

/// Fenêtre glissante 3 s min / 30 s max. OK si σ(roll lissé) < 0,2° sur 3 s.
AdaptiveTareEval evaluateAdaptiveTare({
  required List<TareSample> samples,
  required DateTime startedAt,
  required DateTime now,
  double minWindowS = 3,
  double maxWindowS = 30,
  double maxSigmaDeg = 0.2,
}) {
  final durationS = now.difference(startedAt).inMilliseconds / 1000.0;
  final cut = now.subtract(
    Duration(milliseconds: (minWindowS * 1000).round()),
  );
  final window = <double>[
    for (final s in samples)
      if (!s.t.isBefore(cut)) s.rollDeg,
  ];
  final r = computeTare(window, maxSigmaDeg: maxSigmaDeg);
  if (durationS < minWindowS) {
    return AdaptiveTareEval(
      complete: false,
      ok: false,
      approx: false,
      offsetDeg: r.offsetDeg,
      sigmaDeg: r.sigmaDeg,
      durationS: durationS,
    );
  }
  if (r.ok) {
    return AdaptiveTareEval(
      complete: true,
      ok: true,
      approx: false,
      offsetDeg: r.offsetDeg,
      sigmaDeg: r.sigmaDeg,
      durationS: durationS,
    );
  }
  if (durationS >= maxWindowS) {
    return AdaptiveTareEval(
      complete: true,
      ok: false,
      approx: true,
      offsetDeg: r.sigmaDeg.isFinite ? r.offsetDeg : 0,
      sigmaDeg: r.sigmaDeg,
      durationS: durationS,
    );
  }
  return AdaptiveTareEval(
    complete: false,
    ok: false,
    approx: false,
    offsetDeg: r.offsetDeg,
    sigmaDeg: r.sigmaDeg,
    durationS: durationS,
  );
}

double emaFilter(double previous, double sample, {double alpha = 0.15}) {
  return alpha * sample + (1 - alpha) * previous;
}
