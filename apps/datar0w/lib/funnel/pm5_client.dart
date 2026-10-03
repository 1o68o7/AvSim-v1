import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Appareil PM5 vu au scan (Concept2).
class Pm5Hit {
  const Pm5Hit({
    required this.id,
    required this.name,
    required this.rssi,
  });

  final String id;
  final String name;
  final int rssi;
}

/// Télémétrie live PM5 (Lot 3). Pas de calories.
class Pm5LiveTick {
  const Pm5LiveTick({
    required this.elapsedS,
    required this.distM,
    required this.split500S,
    required this.cadence,
    required this.watts,
    required this.dragFactor,
  });

  final double elapsedS;
  final int distM;
  final double split500S;
  final double cadence;
  final double watts;
  final int dragFactor;
}

/// Abstraction PM5. Fake en CI / desktop ; vrai GATT = Lot ultérieur.
abstract class Pm5Client {
  Stream<List<Pm5Hit>> get hits;
  Stream<Pm5LiveTick> get ticks;
  String? get connectedId;
  int? get lastDragFactor;
  Future<void> startScan({Duration timeout = const Duration(seconds: 6)});
  Future<void> stopScan();
  Future<bool> connect(String id);
  Future<void> disconnect();
  Future<void> startWorkout({required int targetDistM});
  Future<void> stopWorkout();
}

/// Simulateur PM5 : DF live + progression distance/split/cadence/watts.
class FakePm5Client implements Pm5Client {
  FakePm5Client({
    this.connectOk = true,
    List<Pm5Hit>? hits,
    this.seedDragFactor = 118,
  }) : seedHits = hits ??
            const [
              Pm5Hit(id: 'c2-48291', name: 'PM5 · C2-48291', rssi: -48),
              Pm5Hit(id: 'c2-11902', name: 'PM5 · C2-11902', rssi: -67),
            ];

  final bool connectOk;
  final List<Pm5Hit> seedHits;
  final int seedDragFactor;

  final _hits = StreamController<List<Pm5Hit>>.broadcast();
  final _ticks = StreamController<Pm5LiveTick>.broadcast();
  Timer? _tickTimer;
  String? _connectedId;
  int? _lastDf;
  DateTime? _startedAt;
  int _targetDistM = 2000;
  final _rng = Random(42);

  @override
  Stream<List<Pm5Hit>> get hits => _hits.stream;

  @override
  Stream<Pm5LiveTick> get ticks => _ticks.stream;

  @override
  String? get connectedId => _connectedId;

  @override
  int? get lastDragFactor => _lastDf;

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 6)}) async {
    _hits.add(seedHits);
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<bool> connect(String id) async {
    if (!connectOk) return false;
    _connectedId = id;
    _lastDf = seedDragFactor;
    // Tick idle avec DF live dès la connexion.
    _ticks.add(
      Pm5LiveTick(
        elapsedS: 0,
        distM: 0,
        split500S: 0,
        cadence: 0,
        watts: 0,
        dragFactor: _lastDf!,
      ),
    );
    return true;
  }

  @override
  Future<void> disconnect() async {
    await stopWorkout();
    _connectedId = null;
  }

  @override
  Future<void> startWorkout({required int targetDistM}) async {
    if (_connectedId == null) return;
    _targetDistM = targetDistM > 0 ? targetDistM : 2000;
    _startedAt = DateTime.now();
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      final started = _startedAt;
      if (started == null) return;
      final elapsed = DateTime.now().difference(started).inMilliseconds / 1000.0;
      // ~1:55 /500 → ~4.35 m/s
      final pace = 115.0 + _rng.nextDouble() * 4; // split s
      final speed = 500.0 / pace;
      final dist = (elapsed * speed).round().clamp(0, _targetDistM);
      final cad = 26 + _rng.nextInt(5);
      final watts = 200 + _rng.nextInt(60);
      // DF live : dérive ±2 autour du seed.
      _lastDf = (seedDragFactor + _rng.nextInt(5) - 2).clamp(90, 140);
      _ticks.add(
        Pm5LiveTick(
          elapsedS: elapsed,
          distM: dist,
          split500S: pace,
          cadence: cad.toDouble(),
          watts: watts.toDouble(),
          dragFactor: _lastDf!,
        ),
      );
    });
  }

  @override
  Future<void> stopWorkout() async {
    _tickTimer?.cancel();
    _tickTimer = null;
    _startedAt = null;
  }

  void dispose() {
    _tickTimer?.cancel();
    _hits.close();
    _ticks.close();
  }
}

final pm5ClientProvider = Provider<Pm5Client>((ref) {
  final client = FakePm5Client();
  ref.onDispose(client.dispose);
  return client;
});
