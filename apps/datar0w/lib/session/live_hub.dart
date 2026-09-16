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
import 'tare_math.dart';

enum TareStatus { none, running, ok, failed }

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
    this.tareStatus = TareStatus.none,
    this.tareOffset,
    this.tareSigma,
    this.tareElapsedS = 0,
    this.logging = false,
    this.code,
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
  final TareStatus tareStatus;
  final double? tareOffset;
  final double? tareSigma;
  final int tareElapsedS;
  final bool logging;
  final String? code;

  bool get tareOk => tareStatus == TareStatus.ok && tareOffset != null;

  /// Gîte live = roll − offset (lot C). Sans tare : null.
  double? get giteDeg {
    if (rollDeg == null || tareOffset == null) return null;
    return rollDeg! - tareOffset!;
  }

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
    TareStatus? tareStatus,
    double? tareOffset,
    double? tareSigma,
    int? tareElapsedS,
    bool? logging,
    String? code,
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
      tareStatus: tareStatus ?? this.tareStatus,
      tareOffset: tareOffset ?? this.tareOffset,
      tareSigma: tareSigma ?? this.tareSigma,
      tareElapsedS: tareElapsedS ?? this.tareElapsedS,
      logging: logging ?? this.logging,
      code: code ?? this.code,
    );
  }
}

class LiveHub extends Notifier<LiveHubState> {
  final GpsService _gps = GpsService();
  final ImuService _imu = ImuService();
  final BatteryService _battery = BatteryService();
  final NetService _net = NetService();

  final List<StreamSubscription<dynamic>> _imuSubs = [];
  final List<StreamSubscription<dynamic>> _sessionSubs = [];
  Timer? _tick;
  Timer? _tareTicker;
  SessionStore? _store;
  GpsFix? _lastFix;
  GpsFix? _lastGoodFix;
  double _dist = 0;
  DateTime? _lastGpsAt;
  bool _imuOn = false;
  double? _emaRoll;
  final List<double> _tareWindow = [];
  DateTime? _tareStartedAt;

  @override
  LiveHubState build() {
    ref.onDispose(() {
      unawaited(_disposeAll());
    });
    return const LiveHubState();
  }

  Future<void> listenImu() async {
    if (_imuOn) return;
    _imuOn = true;
    _imuSubs.add(
      _imu.rollStream().listen(
        (s) {
          _emaRoll = _emaRoll == null
              ? s.rollDeg
              : emaFilter(_emaRoll!, s.rollDeg);
          if (state.tareStatus == TareStatus.running && _emaRoll != null) {
            _tareWindow.add(_emaRoll!);
          }
          state = state.copyWith(rollDeg: s.rollDeg, pitchDeg: s.pitchDeg);
        },
        onError: (_) {},
      ),
    );
  }

  void beginTare() {
    if (state.tareStatus == TareStatus.running) return;
    _tareWindow.clear();
    _tareStartedAt = DateTime.now();
    state = state.copyWith(
      tareStatus: TareStatus.running,
      tareElapsedS: 0,
      tareSigma: null,
    );
    _tareTicker?.cancel();
    _tareTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final start = _tareStartedAt;
      if (start == null) return;
      final s = DateTime.now().difference(start).inSeconds;
      state = state.copyWith(tareElapsedS: s.clamp(0, 30));
      if (s >= 30) {
        _finishTare();
      }
    });
  }

  void _finishTare() {
    _tareTicker?.cancel();
    _tareTicker = null;
    final result = computeTare(_tareWindow);
    _tareWindow.clear();
    state = state.copyWith(
      tareStatus: result.ok ? TareStatus.ok : TareStatus.failed,
      tareOffset: result.ok ? result.offsetDeg : state.tareOffset,
      tareSigma: result.sigmaDeg.isFinite ? result.sigmaDeg : null,
      tareElapsedS: 30,
    );
  }

  /// Démarrer : meta.json (offset) + logger 1 Hz. Pas avant tare OK.
  Future<bool> startSession() async {
    if (!state.tareOk || _store != null) return false;
    final perm = await AppPermissions.requestSession();
    state = state.copyWith(
      locationOk: perm.locationOk,
      permissionMessage: perm.message ?? '',
    );

    final id = 's${DateTime.now().millisecondsSinceEpoch}';
    final store = SessionStore(id);
    final dir = await store.open(tareOffset: state.tareOffset!);
    _store = store;
    _dist = 0;
    _lastFix = null;
    _lastGoodFix = null;
    _lastGpsAt = null;

    state = state.copyWith(
      sessionId: id,
      sessionDir: dir.path,
      logging: true,
      sampleCount: 0,
      distM: 0,
    );

    await listenImu();

    if (perm.locationOk) {
      _sessionSubs.add(
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

    _sessionSubs.add(_net.stream().listen((n) => state = state.copyWith(net: n)));
    state = state.copyWith(net: await _net.current());

    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _writeSample());
    return true;
  }

  Future<void> _writeSample() async {
    if (!state.logging || _store == null) return;
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
      giteDeg: state.giteDeg,
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

  Future<void> stopSession() async {
    _tick?.cancel();
    _tick = null;
    for (final s in _sessionSubs) {
      await s.cancel();
    }
    _sessionSubs.clear();
    await _store?.markEnded();
    await _store?.close();
    _store = null;
    state = state.copyWith(logging: false);
  }

  Future<void> _disposeAll() async {
    _tareTicker?.cancel();
    await stopSession();
    for (final s in _imuSubs) {
      await s.cancel();
    }
    _imuSubs.clear();
    _imuOn = false;
  }
}

final liveHubProvider = NotifierProvider<LiveHub, LiveHubState>(LiveHub.new);
