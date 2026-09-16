import 'package:datar0w/session/model.dart';
import 'package:datar0w/session/summary.dart';
import 'package:flutter_test/flutter_test.dart';

SessionSample _s({
  required int t,
  double? lat,
  double? lon,
  double dist = 0,
  double? sog,
  double? gite,
}) {
  return SessionSample(
    t: t,
    lat: lat,
    lon: lon,
    distM: dist,
    sog: sog,
    giteDeg: gite,
    net: 'wifi',
  );
}

void main() {
  test('trou GPS coupe le polyline, pas d’interpolation', () {
    final segs = gpsSegments([
      _s(t: 1, lat: 48, lon: 2),
      _s(t: 2, lat: 48.001, lon: 2.001),
      _s(t: 3),
      _s(t: 4, lat: 48.002, lon: 2.002),
    ]);
    expect(segs.length, 2);
    expect(segs.first.length, 2);
    expect(segs.last.length, 1);
  });

  test('gîte RMS et cadence nullable', () {
    final sum = SessionSummary.fromSamples([
      _s(t: 0, gite: 3, dist: 0),
      _s(t: 1000, gite: -3, dist: 10),
    ]);
    expect(sum.giteRms, closeTo(3, 1e-9));
    expect(sum.cadenceMean, isNull);
    expect(sum.distM, 10);
  });
}
