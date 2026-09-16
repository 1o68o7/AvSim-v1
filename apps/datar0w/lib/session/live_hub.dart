import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sensors/battery.dart';
import '../sensors/geo.dart';
import '../sensors/gps.dart';
import '../sensors/imu.dart';
import '../sensors/net.dart';
import '../sensors/permissions.dart';
import 'model.dart';
import 'store.dart';

class LiveHubState {
  const LiveHubState({
    this.locationOk = false,
    this.permissionMessage,
    this.lat,
    this.lon,
    this.sog,
    this.accH,
    this.rollDeg,
    this.pitchDeg,
    this.batt,
    this.net = 'hors ligne',
    this.distM = 0,
    this.sessionId,
    this.sessionDir,
    this.sampleCount = 0,
    this.gpsLost = true,
  });

  final bool locationOk;
  final String? permissionMessage;
  final double? lat;
  final double? lon;
  final double? sog;
  final double? accH;
  final double? rollDeg;
  final double? pitchDeg;
  final int? batt;
  final String net;
  final double distM;
  final String? sessionId;
  final String? sessionDir;
  final int sampleCount;
  final bool gpsLost;

  LiveHubState copyWith({
    bool? locationOk,
    String? permissionMessage,
    double? lat,
    double? lon,
    double? sog,
    double? accH,
    double? rollDeg,
    double? pitchDeg,
    int? batt,
    String? net,
    double? distM,
    String? sessionId,
    String? sessionDir,
    int? sampleCount,
    bool? gpsLost,
  }) {
    return LiveHubState(
      locationOk: locationOk ?? this.locationOk,
      permissionMessage: permissionMessage ?? this.permissionMessage,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      sog: sog ?? this.sog,
      accH: accH ?? this.accH,
      rollDeg: rollDeg ?? this.rollDeg,
      pitchDeg: pitchDeg ?? this.pitchDeg,
      batt: batt ?? this.batt,
      net: net ?? this.net,
      distM: distM ?? this.distM,
      sessionId: sessionId ?? this.sessionId,
      sessionDir: sessionDir ?? this.sessionDir,
      sampleCount: sampleCount ?? this.sampleCount,
      gpsLost: gpsLost ?? this.gpsLost,
    );
  }
}

class LiveHub extends Notifier<LiveHubState> {
  final GpsService _gps = GpsService();
  final ImuService _imu = ImuService();
  final BatteryService _battery = BatteryService();
  final NetService _net = NetService();

  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _tick;
  SessionStore? _store;
  GpsFix? _lastFix;
  GpsFix? _lastGoodFix;
  double _dist = 0;
  DateTime? _lastGpsAt;

  @override
  LiveHubState build() {
    ref.onDispose(() {
      unawaited(_stop());
    });
    return const LiveHubState();
  }

  Future<void> start() async {
    if (_store != null) return;
    final perm = await AppPermissions.requestSession();
    state = state.copyWith(
      locationOk: perm.locationOk,
      permissionMessage: perm.message ?? '',
    );

    final id = 's${DateTime.now().millisecondsSinceEpoch}';
    final store = SessionStore(id);
    final dir = await store.open();
    _store = store;
    state = state.copyWith(sessionId: id, sessionDir: dir.path);

    _subs.add(
      _imu.rollStream().listen(
        (s) {
          state = state.copyWith(rollDeg: s.rollDeg, pitchDeg: s.pitchDeg);
        },
        onError: (_) {},
      ),
    );

    if (perm.locationOk) {
      _subs.add(
        _gps.stream().listen(
          (fix) {
            _lastFix = fix;
            _lastGpsAt = DateTime.now();
            if (fix.accH == null || fix.accH! < 25) {
              final prev = _lastGoodFix;
              if (prev != null) {
                _dist += haversineMeters(
                  lat1: prev.lat,
                  lon1: prev.lon,
                  lat2: fix.lat,
                  lon2: fix.lon,
                );
              }
              _lastGoodFix = fix;
            }
            state = state.copyWith(
              lat: fix.lat,
              lon: fix.lon,
              sog: fix.sog,
              accH: fix.accH,
              distM: _dist,
              gpsLost: false,
            );
          },
          onError: (_) {
            state = state.copyWith(gpsLost: true);
          },
        ),
      );
    }

    _subs.add(_net.stream().listen((n) => state = state.copyWith(net: n)));
    state = state.copyWith(net: await _net.current());

    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _writeSample());
  }

  Future<void> _writeSample() async {
    final stale = _lastGpsAt == null ||
        DateTime.now().difference(_lastGpsAt!) > const Duration(seconds: 3);
    if (stale) {
      state = state.copyWith(gpsLost: true);
    }
    final batt = await _battery.levelPercent();
    final fix = _lastFix;
    final sample = SessionSample(
      t: DateTime.now().millisecondsSinceEpoch,
      lat: stale ? null : fix?.lat,
      lon: stale ? null : fix?.lon,
      alt: stale ? null : fix?.alt,
      sog: stale ? null : fix?.sog,
      cog: stale ? null : fix?.cog,
      accH: stale ? null : fix?.accH,
      distM: _dist,
      giteDeg: state.rollDeg,
      pitchDeg: state.pitchDeg,
      cadenceSpm: null,
      batt: batt,
      net: state.net,
    );
    _store?.append(sample);
    state = state.copyWith(
      batt: batt,
      sampleCount: state.sampleCount + 1,
    );
  }

  Future<void> _stop() async {
    _tick?.cancel();
    _tick = null;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _store?.close();
    _store = null;
  }
}

final liveHubProvider = NotifierProvider<LiveHub, LiveHubState>(LiveHub.new);
