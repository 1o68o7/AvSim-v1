class DoublePressStop {
  DoublePressStop({this.window = const Duration(seconds: 3)});

  final Duration window;
  DateTime? _first;

  /// true = confirmer l'arrêt.
  bool press({DateTime? now}) {
    final t = now ?? DateTime.now();
    final prev = _first;
    if (prev != null && t.difference(prev) <= window) {
      _first = null;
      return true;
    }
    _first = t;
    return false;
  }
}
