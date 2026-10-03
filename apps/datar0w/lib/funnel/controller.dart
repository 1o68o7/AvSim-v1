import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'store.dart';

final funnelStoreProvider = Provider<FunnelStore>((ref) => FunnelStore());

class FunnelState {
  const FunnelState({
    this.profile,
    this.logs = const [],
    this.loaded = false,
    this.activePiece,
    this.activeDistM,
    this.activeDragFactor,
    this.lastResult,
    this.lastWasPb = false,
    this.pendingOrigin,
  });

  final FunnelProfile? profile;
  final List<ErgSessionLog> logs;
  final bool loaded;
  final ErgPiece? activePiece;
  final int? activeDistM;
  final int? activeDragFactor;
  final ErgSessionLog? lastResult;
  final bool lastWasPb;
  /// Origin one-shot pour le prochain finish (ex. bascule indoor → remplacement).
  final String? pendingOrigin;

  bool get onboardDone => profile?.onboardDone == true;

  ErgPiece get resolvedPiece =>
      activePiece ??
      profile?.todayPiece ??
      ErgPiece.fromDistanceMeters(activeDistM ?? 500);

  FunnelState copyWith({
    FunnelProfile? profile,
    List<ErgSessionLog>? logs,
    bool? loaded,
    ErgPiece? activePiece,
    int? activeDistM,
    int? activeDragFactor,
    ErgSessionLog? lastResult,
    bool? lastWasPb,
    String? pendingOrigin,
    bool clearActive = false,
    bool clearResult = false,
    bool clearPendingOrigin = false,
  }) =>
      FunnelState(
        profile: profile ?? this.profile,
        logs: logs ?? this.logs,
        loaded: loaded ?? this.loaded,
        activePiece: clearActive ? null : (activePiece ?? this.activePiece),
        activeDistM: clearActive ? null : (activeDistM ?? this.activeDistM),
        activeDragFactor:
            clearActive ? null : (activeDragFactor ?? this.activeDragFactor),
        lastResult: clearResult ? null : (lastResult ?? this.lastResult),
        lastWasPb: lastWasPb ?? this.lastWasPb,
        pendingOrigin: clearPendingOrigin
            ? null
            : (pendingOrigin ?? this.pendingOrigin),
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

  void setActivePiece({
    ErgPiece? piece,
    int? distM,
    int? dragFactor,
  }) {
    final resolved = piece ??
        (distM != null ? ErgPiece.fromDistanceMeters(distM) : null) ??
        state.resolvedPiece;
    state = state.copyWith(
      activePiece: resolved,
      activeDistM: resolved.logDistM > 0 ? resolved.logDistM : distM,
      activeDragFactor: dragFactor ?? state.profile?.dragFactor,
    );
  }

  Future<bool> needsBrief(ErgPiece piece) async {
    final key = piece.id;
    final n = await _store.sessionCountForPiece(key);
    if (n > 0) return false;
    // Fallback distance for Lot 1 pieces.
    if (piece.logDistM > 0) {
      return (await _store.sessionCountForDistance(piece.logDistM)) < 1;
    }
    return true;
  }

  void setPendingOrigin(String? origin) {
    state = state.copyWith(
      pendingOrigin: origin,
      clearPendingOrigin: origin == null,
    );
  }

  Future<ErgSessionLog> finishSession({
    required ErgPiece piece,
    required double durationS,
    double? cadence,
    double? watts,
    int? dragFactor,
    bool? complete,
    int? realizedDistM,
    List<int> blockCadences = const [],
    String? origin,
  }) async {
    final resolvedOrigin = origin ?? state.pendingOrigin ?? 'indoor';
    final distM = piece.logDistM;
    final done = complete ?? (durationS > 0);
    final splitDist = realizedDistM ?? (distM > 0 ? distM : 500);
    final split = split500Seconds(durationS: durationS, distM: splitDist);
    final prior = List<ErgSessionLog>.from(state.logs);
    final log = ErgSessionLog(
      distM: distM,
      durationS: durationS,
      split500S: split,
      cadence: cadence,
      watts: watts,
      dragFactor: dragFactor ?? state.activeDragFactor ?? state.profile?.dragFactor,
      complete: done,
      origin: resolvedOrigin,
      pieceId: piece.id,
      realizedDistM: realizedDistM,
      blockCadences: blockCadences,
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
      activePiece: piece,
      activeDistM: distM > 0 ? distM : state.activeDistM,
      clearPendingOrigin: true,
    );
    return log;
  }

  void bookNext({ErgPiece? piece, int? distM}) {
    final p = state.profile;
    if (p == null) return;
    if (piece != null) {
      saveProfile(
        p.copyWith(
          todayPieceId: piece.id,
          todayDistanceM: piece.logDistM,
          clearTodayDuration: true,
        ),
      );
      return;
    }
    if (distM != null) {
      saveProfile(
        p.copyWith(
          todayDistanceM: distM,
          clearTodayDuration: true,
          clearTodayPiece: true,
        ),
      );
    }
  }
}

final funnelProvider =
    NotifierProvider<FunnelController, FunnelState>(FunnelController.new);
