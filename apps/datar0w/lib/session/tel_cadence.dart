/// Cadence téléphone : pics d’accélération longitudinale.
/// 6 périodes stables (écart max-min / médiane < 15 %), sinon null.
class TelCadenceDetector {
  TelCadenceDetector({
    this.minPeriodS = 0.4,
    this.maxPeriodS = 2.5,
    this.peakThresh = 1.2,
    this.stableN = 6,
    this.maxSpread = 0.15,
  });

  final double minPeriodS;
  final double maxPeriodS;
  final double peakThresh;
  final int stableN;
  final double maxSpread;

  double _hp = 0;
  double _prevRaw = 0;
  bool _armed = false;
  DateTime? _lastPeak;
  final List<double> _periods = [];
  double? spm;

  void reset() {
    _hp = 0;
    _prevRaw = 0;
    _armed = false;
    _lastPeak = null;
    _periods.clear();
    spm = null;
  }

  void add({required double alongMps2, required DateTime now}) {
    _hp = 0.85 * (_hp + alongMps2 - _prevRaw);
    _prevRaw = alongMps2;

    if (!_armed && _hp > peakThresh) {
      _armed = true;
    } else if (_armed && _hp < peakThresh * 0.45) {
      _armed = false;
      final prev = _lastPeak;
      _lastPeak = now;
      if (prev != null) {
        final p = now.difference(prev).inMicroseconds / 1e6;
        if (p >= minPeriodS && p <= maxPeriodS) {
          _periods.add(p);
          if (_periods.length > stableN) {
            _periods.removeAt(0);
          }
        } else {
          _periods.clear();
        }
      }
      _recompute();
    }
  }

  void _recompute() {
    if (_periods.length < stableN) {
      spm = null;
      return;
    }
    final sorted = [..._periods]..sort();
    final med = sorted[sorted.length ~/ 2];
    if (med <= 0) {
      spm = null;
      return;
    }
    final spread = (sorted.last - sorted.first) / med;
    if (spread > maxSpread) {
      spm = null;
      return;
    }
    spm = 60.0 / med;
  }
}
