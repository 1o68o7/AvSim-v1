import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../sensors/baro.dart';
import '../sensors/battery.dart';
import '../sensors/geo.dart';
import '../sensors/gps.dart';
import '../sensors/imu.dart';
import '../sensors/mag_heading.dart';
import '../sensors/net.dart';
import '../sensors/permissions.dart';
import 'api_client.dart';
import 'boat_config.dart';
import 'code.dart';
import 'heel.dart';
import 'model.dart';
import 'rower_orientation.dart';
import 'session_fgs.dart';
import 'store.dart';
import 'tare_math.dart';
import 'tel_cadence.dart';

enum TareStatus { none, running, ok, approx, failed }

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
    this.tareQuality,
    this.tareDurationS,
    this.logging = false,
    this.code,
    this.coachSessionId,
    this.coachFromApi = false,
    this.remoteSample,
    this.displayGiteDeg,
    this.imuOk = false,
    this.imuHint = 'IMU : en attente du niveau du téléphone…',
    this.tareSampleCount = 0,
    this.ax,
    this.ay,
    this.az,
    this.cadenceSpm,
    this.hdgMag,
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
  final String? tareQuality;
  final double? tareDurationS;
  final bool logging;
  final String? code;
  final String? coachSessionId;
  final bool coachFromApi;
  final SessionSample? remoteSample;
  final double? displayGiteDeg;
  final bool imuOk;
  final String imuHint;
  final int tareSampleCount;
  final double? ax;
  final double? ay;
  final double? az;
  final double? cadenceSpm;
  final double? hdgMag;

  bool get tareOk =>
      tareOffset != null &&
      (tareStatus == TareStatus.ok || tareStatus == TareStatus.approx);

  bool get tareWeak => tareStatus == TareStatus.approx;

  /// Gîte jsonl : roll écran lissé − offset. + = tribords = gauche écran en bas.
  double? get giteDeg {
    if (rollDeg == null || tareOffset == null) return null;
    return rowerGiteFromImu(rollDeg! - tareOffset!);
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
    String? tareQuality,
    double? tareDurationS,
    bool? logging,
    String? code,
    String? coachSessionId,
    bool? coachFromApi,
    SessionSample? remoteSample,
    double? displayGiteDeg,
    bool? imuOk,
    String? imuHint,
    int? tareSampleCount,
    double? ax,
    double? ay,
    double? az,
    double? cadenceSpm,
    double? hdgMag,
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
      tareQuality: tareQuality ?? this.tareQuality,
      tareDurationS: tareDurationS ?? this.tareDurationS,
      logging: logging ?? this.logging,
      code: code ?? this.code,
      coachSessionId: coachSessionId ?? this.coachSessionId,
      coachFromApi: coachFromApi ?? this.coachFromApi,
      remoteSample: remoteSample ?? this.remoteSample,
      displayGiteDeg: displayGiteDeg ?? this.displayGiteDeg,
      imuOk: imuOk ?? this.imuOk,
      imuHint: imuHint ?? this.imuHint,
      tareSampleCount: tareSampleCount ?? this.tareSampleCount,
      ax: ax ?? this.ax,
      ay: ay ?? this.ay,
      az: az ?? this.az,
      cadenceSpm: cadenceSpm ?? this.cadenceSpm,
      hdgMag: hdgMag ?? this.hdgMag,
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
  Timer? _uiTimer;
  Timer? _coachPoll;
  SessionStore? _store;
  final SessionApi _api = SessionApi();
  final List<SessionSample> recorded = [];
  GpsFix? _lastFix;
  GpsFix? _lastGoodFix;
  double _dist = 0;
  DateTime? _lastGpsAt;
  bool _imuOn = false;
  int _displayRotationDeg = 0;
  int? _tareRotationDeg;
  final HeelFilter _heel = HeelFilter();
  ImuFrame? _lastImu;
  DateTime? _lastImuLogAt;
  double? _displayGite;
  final List<TareSample> _tareWindow = [];
  DateTime? _tareStartedAt;
  final TelCadenceDetector _cadence = TelCadenceDetector();
  double? _mx;
  double? _my;
  double? _mz;
  double? _pHpa;
  double? _p0Hpa;
  bool _extraOn = false;

  @override
  LiveHubState build() {
    ref.onDispose(() {
      unawaited(_disposeAll());
    });
    return const LiveHubState();
  }

  /// Rotation UI 0/90/180/270 — suit l’écran (gauche/droite visibles).
  /// Figée pendant la tare pour que l’offset soit le vrai niveau du téléphone.
  void setDisplayRotation(int deg) {
    if (state.tareStatus == TareStatus.running) return;
    _displayRotationDeg = normalizeDisplayRotationDeg(deg);
  }

  int get _heelRotationDeg =>
      _tareRotationDeg ?? _displayRotationDeg;

  Future<void> listenImu() async {
    _uiTimer ??= Timer.periodic(const Duration(milliseconds: 80), (_) {
      _publishUi();
    });
    if (_imuOn) return;
    _imuOn = true;
    _imuSubs.add(
      _imu.frameStream().listen(
        (f) {
          _lastImu = f;
          final roll = screenHeelDeg(
            f.ax,
            f.ay,
            f.az,
            displayRotationDeg: _heelRotationDeg,
          );
          _heel.update(
            accelRollDeg: roll,
            gyroDegPerS: screenHeelGyroDegPerS(
              f.gx,
              f.gy,
              f.gz,
              displayRotationDeg: _heelRotationDeg,
            ),
          );
          final filtered = _heel.filteredDeg;
          if (state.tareStatus == TareStatus.running && filtered != null) {
            final t = DateTime.now();
            _tareWindow.add(TareSample(t: t, rollDeg: filtered));
            final cut = t.subtract(const Duration(seconds: 32));
            _tareWindow.removeWhere((s) => s.t.isBefore(cut));
          }
          _maybeLogImu(f);
          if (state.logging) {
            final along = deviceToScreenVec(
              f.ax,
              f.ay,
              f.az,
              displayRotationDeg: _heelRotationDeg,
            ).x;
            _cadence.add(alongMps2: along, now: DateTime.now());
          }
        },
        onError: (Object e) {
          state = state.copyWith(
            imuOk: false,
            imuHint: 'IMU erreur : $e',
          );
        },
      ),
    );
    _listenPhoneExtras();
  }

  void _listenPhoneExtras() {
    if (_extraOn) return;
    _extraOn = true;
    try {
      _imuSubs.add(
        magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval)
            .listen(
          (e) {
            _mx = e.x;
            _my = e.y;
            _mz = e.z;
          },
          onError: (_) {},
        ),
      );
    } catch (_) {}
    try {
      _imuSubs.add(
        barometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
          (e) {
            _pHpa = e.pressure;
            _p0Hpa ??= e.pressure;
          },
          onError: (_) {},
        ),
      );
    } catch (_) {}
  }

  void _publishUi() {
    final imu = _lastImu;
    final f = _heel.filteredDeg;
    if (imu == null && f == null) {
      if (state.tareStatus == TareStatus.running &&
          state.tareElapsedS >= 2 &&
          _tareWindow.isEmpty) {
        state = state.copyWith(
          imuHint:
              'IMU muet : le niveau du téléphone n’est pas lu. Vérifier que le capteur n’est pas bloqué.',
        );
      }
      return;
    }
    final running = state.tareStatus == TareStatus.running;
    final gite = (running || state.tareOffset == null || f == null)
        ? rowerGiteFromImu(f ?? 0)
        : rowerGiteFromImu(f - state.tareOffset!);
    _displayGite = running
        ? gite
        : clampHeel(displayDeadband(_displayGite, gite));
    final mag = imu == null
        ? null
        : hypot3(imu.ax, imu.ay, imu.az);
    state = state.copyWith(
      rollDeg: f,
      pitchDeg: imu?.accelPitchDeg,
      displayGiteDeg: _displayGite,
      imuOk: imu != null,
      imuHint: imu == null
          ? state.imuHint
          : 'IMU niveau  |a|=${mag!.toStringAsFixed(2)} m/s²  '
              'ax=${imu.ax.toStringAsFixed(2)}  '
              'ay=${imu.ay.toStringAsFixed(2)}  '
              'az=${imu.az.toStringAsFixed(2)}',
      tareSampleCount: _tareWindow.length,
      ax: imu?.ax,
      ay: imu?.ay,
      az: imu?.az,
    );
    _maybeCompleteTare();
  }

  void _maybeLogImu(ImuFrame f) {
    if (!state.logging || _store == null) return;
    final now = DateTime.now();
    if (_lastImuLogAt != null &&
        now.difference(_lastImuLogAt!) < const Duration(milliseconds: 50)) {
      return;
    }
    _lastImuLogAt = now;
    _store?.appendImuLine(
      jsonEncode({
        't': now.millisecondsSinceEpoch,
        'ax': f.ax,
        'ay': f.ay,
        'az': f.az,
        'gx': f.gx,
        'gy': f.gy,
        'gz': f.gz,
        'roll_raw': f.accelRollDeg,
        'pitch_raw': f.accelPitchDeg,
      }),
    );
  }

  void beginTare() {
    if (state.tareStatus == TareStatus.running) return;
    unawaited(listenImu());
    _heel.reset();
    _displayGite = null;
    _tareWindow.clear();
    _tareStartedAt = DateTime.now();
    _tareRotationDeg = _displayRotationDeg;
    state = state.copyWith(
      tareStatus: TareStatus.running,
      tareElapsedS: 0,
      tareSampleCount: 0,
      imuHint: state.imuOk
          ? state.imuHint
          : 'Tare : lecture du niveau IMU…',
    );
    _tareTicker?.cancel();
    _tareTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _maybeCompleteTare();
    });
  }

  void _maybeCompleteTare() {
    if (state.tareStatus != TareStatus.running) return;
    final start = _tareStartedAt;
    if (start == null) return;
    final now = DateTime.now();
    final eval = evaluateAdaptiveTare(
      samples: _tareWindow,
      startedAt: start,
      now: now,
    );
    final elapsed = eval.durationS.round().clamp(0, 30);
    if (!eval.complete) {
      state = state.copyWith(
        tareElapsedS: elapsed,
        tareSampleCount: _tareWindow.length,
        tareSigma: eval.sigmaDeg.isFinite ? eval.sigmaDeg : state.tareSigma,
      );
      return;
    }
    _applyTare(eval);
  }

  void _applyTare(AdaptiveTareEval eval) {
    _tareTicker?.cancel();
    _tareTicker = null;
    final n = _tareWindow.length;
    state = state.copyWith(
      tareStatus: eval.ok ? TareStatus.ok : TareStatus.approx,
      tareOffset: eval.offsetDeg,
      tareSigma: eval.sigmaDeg.isFinite ? eval.sigmaDeg : null,
      tareElapsedS: eval.durationS.round().clamp(0, 30),
      tareQuality: eval.quality,
      tareDurationS: eval.durationS,
      tareSampleCount: n,
      imuHint: eval.ok
          ? 'Tare OK — zéro = niveau actuel du téléphone (${eval.offsetDeg.toStringAsFixed(2)}°)'
          : 'Tare approximative : σ ${eval.sigmaDeg.isFinite ? eval.sigmaDeg.toStringAsFixed(2) : "—"}° ≥ 0,2° (Démarrer autorisé).',
    );
  }

  /// Démarrer : meta.json (offset) + logger 1 Hz. Pas avant tare OK.
  Future<bool> startSession() async {
    if (!state.tareOk || _store != null) return false;
    final perm = await AppPermissions.requestSession();
    if (perm.locationOk) {
      await AppPermissions.requestBackgroundAfterWhenInUse();
    }
    state = state.copyWith(
      locationOk: perm.locationOk,
      permissionMessage: perm.message ?? '',
    );

    final id = 's${DateTime.now().millisecondsSinceEpoch}';
    final code = generateSessionCode();
    final boat = ref.read(boatConfigProvider);
    final store = SessionStore(id);
    final dir = await store.open(
      tareOffset: state.tareOffset!,
      tareQuality: state.tareQuality ?? (state.tareWeak ? 'approx' : 'ok'),
      tareDurationS: state.tareDurationS ?? state.tareElapsedS.toDouble(),
      code: code,
      bassin: boat.bassin,
      classe: boat.classe,
      seats: boat.seats,
      cox: boat.coxed,
      role: boat.role.wire,
      seatIndex: boat.clampedSeat,
    );
    _store = store;
    recorded.clear();
    _dist = 0;
    _lastFix = null;
    _lastGoodFix = null;
    _lastGpsAt = null;
    _cadence.reset();
    _p0Hpa = _pHpa;

    state = state.copyWith(
      sessionId: id,
      sessionDir: dir.path,
      logging: true,
      sampleCount: 0,
      distM: 0,
      code: code,
    );
    unawaited(_api.createSession(
      id: id,
      code: code,
      meta: {
        ...boat.toMetaFields(),
        'tareOffsetDeg': state.tareOffset,
        'tareQuality': state.tareQuality ?? (state.tareWeak ? 'approx' : 'ok'),
        'tareDurationS': state.tareDurationS ?? state.tareElapsedS.toDouble(),
      },
    ));
    // Échec HTTP : le logger local continue (fichier + tick 1 Hz).

    try {
      await WakelockPlus.enable();
    } catch (_) {}
    await startSessionForeground();
    unawaited(lockRowerLandscape());

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
    final imu = _lastImu;
    final hdg = (imu != null && _mx != null && _my != null && _mz != null)
        ? magHeadingDeg(
            mx: _mx!,
            my: _my!,
            mz: _mz!,
            ax: imu.ax,
            ay: imu.ay,
            az: imu.az,
          )
        : null;
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
      pitchDeg: _lastImu?.accelPitchDeg ?? state.pitchDeg,
      cadenceSpm: _cadence.spm,
      cadenceSrc: _cadence.spm == null ? null : 'tel',
      hdgMag: hdg,
      pHpa: _pHpa,
      altBaro: altBaroRelM(_pHpa, _p0Hpa),
      batt: batt,
      net: state.net,
    );
    _store?.append(sample);
    recorded.add(sample);
    final sid = state.sessionId;
    if (sid != null) {
      unawaited(_api.tick(id: sid, sample: sample));
    }
    state = state.copyWith(
      batt: batt,
      sampleCount: state.sampleCount + 1,
      cadenceSpm: _cadence.spm,
      hdgMag: hdg,
    );
  }

  Future<void> stop() => stopSession();

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
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    await stopSessionForeground();
    unawaited(unlockRowerOrientations());
    _cadence.reset();
    state = state.copyWith(logging: false);
  }

  Future<String?> joinAsCoach(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      final last = state.sessionId ?? await SessionStore.latestId();
      if (last == null) return null;
      state = state.copyWith(
        coachSessionId: last,
        coachFromApi: false,
      );
      return last;
    }
    if (state.code?.toUpperCase() == code && state.sessionId != null) {
      state = state.copyWith(
        coachSessionId: state.sessionId,
        coachFromApi: false,
      );
      return state.sessionId;
    }
    final local = await SessionStore.findIdByCode(code);
    if (local != null) {
      state = state.copyWith(coachSessionId: local, coachFromApi: false);
      return local;
    }
    final remote = await _api.lookupByCode(code);
    if (remote == null) return null;
    state = state.copyWith(
      coachSessionId: remote.id,
      code: remote.code,
      coachFromApi: true,
    );
    return remote.id;
  }

  Future<String?> joinRemoteLive(String rawCode) async {
    final remote = await _api.lookupByCode(rawCode);
    if (remote == null) return null;
    state = state.copyWith(
      coachSessionId: remote.id,
      code: remote.code,
      coachFromApi: true,
    );
    return remote.id;
  }

  void startCoachPoll() {
    _coachPoll?.cancel();
    if (!state.coachFromApi || state.coachSessionId == null) return;
    _coachPoll = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_pollCoach());
    });
    unawaited(_pollCoach());
  }

  void stopCoachPoll() {
    _coachPoll?.cancel();
    _coachPoll = null;
  }

  Future<void> _pollCoach() async {
    final id = state.coachSessionId;
    if (id == null || !state.coachFromApi) return;
    final live = await _api.fetchLive(id);
    if (live == null) return;
    state = state.copyWith(remoteSample: live.sample);
  }

  Future<void> annotate() async {
    final sample = state.coachFromApi ? state.remoteSample : null;
    final id = state.coachSessionId ?? state.sessionId;
    final note = {
      't': DateTime.now().millisecondsSinceEpoch,
      'lat': sample?.lat ?? state.lat,
      'lon': sample?.lon ?? state.lon,
      'sog': sample?.sog ?? state.sog,
      'dist_m': sample?.distM ?? state.distM,
      'gite_deg': sample?.giteDeg ?? state.giteDeg,
    };
    if (_store != null) {
      await _store!.appendNote(note);
    } else if (id != null && !state.coachFromApi) {
      await SessionStore.appendNoteToId(id, note);
    }
    if (id != null) {
      unawaited(_api.note(id: id, note: note));
    }
  }

  Future<void> _disposeAll() async {
    _tareTicker?.cancel();
    stopCoachPoll();
    _uiTimer?.cancel();
    _uiTimer = null;
    await stopSession();
    for (final s in _imuSubs) {
      await s.cancel();
    }
    _imuSubs.clear();
    _imuOn = false;
  }
}

final liveHubProvider = NotifierProvider<LiveHub, LiveHubState>(LiveHub.new);
