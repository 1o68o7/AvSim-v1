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

double emaFilter(double previous, double sample, {double alpha = 0.15}) {
  return alpha * sample + (1 - alpha) * previous;
}
