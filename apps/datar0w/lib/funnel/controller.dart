import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'store.dart';

final funnelStoreProvider = Provider<FunnelStore>((ref) => FunnelStore());

class FunnelState {
  const FunnelState({
    this.profile,
    this.logs = const [],
    this.loaded = false,
    this.activeDistM,
    this.activeDragFactor,
    this.lastResult,
    this.lastWasPb = false,
  });

  final FunnelProfile? profile;
  final List<ErgSessionLog> logs;
  final bool loaded;
  final int? activeDistM;
  final int? activeDragFactor;
  final ErgSessionLog? lastResult;
  final bool lastWasPb;

  bool get onboardDone => profile?.onboardDone == true;

  FunnelState copyWith({
    FunnelProfile? profile,
    List<ErgSessionLog>? logs,
    bool? loaded,
    int? activeDistM,
    int? activeDragFactor,
    ErgSessionLog? lastResult,
    bool? lastWasPb,
    bool clearActive = false,
    bool clearResult = false,
  }) =>
      FunnelState(
        profile: profile ?? this.profile,
        logs: logs ?? this.logs,
        loaded: loaded ?? this.loaded,
        activeDistM: clearActive ? null : (activeDistM ?? this.activeDistM),
        activeDragFactor:
            clearActive ? null : (activeDragFactor ?? this.activeDragFactor),
        lastResult: clearResult ? null : (lastResult ?? this.lastResult),
        lastWasPb: lastWasPb ?? this.lastWasPb,
      );
}

class FunnelController extends Notifier<FunnelState> {
  FunnelStore get _store => ref.read(funnelStoreProvider);

  @override
  FunnelState build() {
    Future<void>.microtask(reload);
    return const FunnelState();
  }

  Future<void> reload() async {
    final profile = await _store.loadProfile();
    final logs = await _store.loadLogs();
    final pb = personalBestSeconds(logs, ErgDistance.m2000.meters);
    final synced = profile == null
        ? null
        : profile.copyWith(pb2000s: pb ?? profile.pb2000s);
    state = state.copyWith(
      profile: synced,
      logs: logs,
      loaded: true,
    );
  }

  Future<void> saveProfile(FunnelProfile profile) async {
    await _store.saveProfile(profile);
    state = state.copyWith(profile: profile, loaded: true);
  }

  Future<void> completeOnboard(FunnelProfile profile) async {
    final done = profile.copyWith(onboardDone: true);
    await saveProfile(done);
  }

  void setActivePiece({required int distM, int? dragFactor}) {
    state = state.copyWith(
      activeDistM: distM,
      activeDragFactor: dragFactor ?? state.profile?.dragFactor,
    );
  }

  Future<bool> needsBrief(int distM) async {
    final n = await _store.sessionCountForDistance(distM);
    return n < 1;
  }

  Future<ErgSessionLog> finishSession({
    required int distM,
    required double durationS,
    double? cadence,
    double? watts,
    int? dragFactor,
    bool? complete,
    String origin = 'indoor',
  }) async {
    final done = complete ?? (durationS > 0);
    // Complet = distance entière (saisie manuelle MVP : flag explicite).
    final split = split500Seconds(durationS: durationS, distM: distM);
    final prior = List<ErgSessionLog>.from(state.logs);
    final log = ErgSessionLog(
      distM: distM,
      durationS: durationS,
      split500S: split,
      cadence: cadence,
      watts: watts,
      dragFactor: dragFactor ?? state.activeDragFactor ?? state.profile?.dragFactor,
      complete: done,
      origin: origin,
      at: DateTime.now().toUtc(),
    );
    final wasPb = isPersonalBest(log: log, prior: prior);
    await _store.addLog(log);
    final logs = [...prior, log];
    final pb2000 = personalBestSeconds(logs, ErgDistance.m2000.meters);
    var profile = state.profile;
    if (profile != null) {
      profile = profile.copyWith(pb2000s: pb2000 ?? profile.pb2000s);
      await _store.saveProfile(profile);
    }
    state = state.copyWith(
      profile: profile,
      logs: logs,
      lastResult: log,
      lastWasPb: wasPb,
      activeDistM: distM,
    );
    return log;
  }

  void bookNext({required int distM}) {
    final p = state.profile;
    if (p == null) return;
    final next = p.copyWith(
      todayDistanceM: distM,
      clearTodayDuration: true,
    );
    // fire-and-forget persist
    saveProfile(next);
  }
}

final funnelProvider =
    NotifierProvider<FunnelController, FunnelState>(FunnelController.new);
