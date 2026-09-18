import 'package:datar0w/session/store.dart';
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

  test('adaptative : σ ok dès 3 s', () {
    final t0 = DateTime.utc(2026, 9, 18);
    final samples = <TareSample>[
      for (var i = 0; i < 40; i++)
        TareSample(
          t: t0.add(Duration(milliseconds: 80 * i)),
          rollDeg: 1.2,
        ),
    ];
    final early = evaluateAdaptiveTare(
      samples: samples.take(10).toList(),
      startedAt: t0,
      now: t0.add(const Duration(milliseconds: 800)),
    );
    expect(early.complete, isFalse);

    final ok = evaluateAdaptiveTare(
      samples: samples,
      startedAt: t0,
      now: t0.add(const Duration(milliseconds: 3200)),
    );
    expect(ok.complete, isTrue);
    expect(ok.ok, isTrue);
    expect(ok.approx, isFalse);
    expect(ok.quality, 'ok');
    expect(ok.durationS, closeTo(3.2, 0.05));
  });

  test('adaptative : 30 s sans σ → approx', () {
    final t0 = DateTime.utc(2026, 9, 18);
    final samples = <TareSample>[
      for (var i = 0; i < 80; i++)
        TareSample(
          t: t0.add(Duration(milliseconds: 400 * i)),
          rollDeg: i.isEven ? 0.0 : 2.0,
        ),
    ];
    final mid = evaluateAdaptiveTare(
      samples: samples,
      startedAt: t0,
      now: t0.add(const Duration(seconds: 10)),
    );
    expect(mid.complete, isFalse);

    final approx = evaluateAdaptiveTare(
      samples: samples,
      startedAt: t0,
      now: t0.add(const Duration(seconds: 30)),
    );
    expect(approx.complete, isTrue);
    expect(approx.ok, isFalse);
    expect(approx.approx, isTrue);
    expect(approx.quality, 'approx');
  });

  test('meta tareQuality ok | approx + durée', () {
    const ok = SessionMeta(
      id: 's1',
      tareOffset: 1.2,
      tareQuality: 'ok',
      tareDurationS: 3.4,
    );
    expect(ok.toJson()['tareOffsetDeg'], 1.2);
    expect(ok.toJson()['tareQuality'], 'ok');
    expect(SessionMeta.fromJson(ok.toJson()).tareDurationS, 3.4);

    const ap = SessionMeta(
      id: 's2',
      tareOffset: 0.5,
      tareQuality: 'approx',
      tareDurationS: 30,
    );
    expect(SessionMeta.fromJson(ap.toJson()).tareQuality, 'approx');
  });
}
