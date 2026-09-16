import 'package:datar0w/session/tare_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tare OK si σ < 0,2°', () {
    final r = computeTare(List.filled(40, 2.5));
    expect(r.ok, isTrue);
    expect(r.offsetDeg, closeTo(2.5, 1e-9));
    expect(r.sigmaDeg, closeTo(0, 1e-9));
  });

  test('tare refusée si σ trop grand', () {
    final samples = <double>[];
    for (var i = 0; i < 40; i++) {
      samples.add(i.isEven ? 0.0 : 1.0);
    }
    final r = computeTare(samples);
    expect(r.ok, isFalse);
    expect(r.sigmaDeg, greaterThan(0.2));
  });
}
