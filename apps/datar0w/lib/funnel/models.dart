/// Funnel rameur Lot 1 — cadres, distances FFA 500/2000, logs locaux.

enum PracticeFrame {
  loisir,
  sante,
  competition,
  para,
  paraAdapte,
  handiSante;

  String get wire => name;

  static PracticeFrame? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  String get label => switch (this) {
        loisir => 'Loisir',
        sante => 'Aviron Santé',
        competition => 'Compétition',
        para => 'Para-aviron',
        paraAdapte => 'Para-aviron adapté',
        handiSante => 'Handi-Santé',
      };
}

enum ErgDistance {
  m500(500),
  m2000(2000);

  const ErgDistance(this.meters);
  final int meters;

  static ErgDistance? fromMeters(int? m) {
    if (m == null) return null;
    for (final v in values) {
      if (v.meters == m) return v;
    }
    return null;
  }

  String get label => switch (this) {
        m500 => '500 m',
        m2000 => '2 000 m',
      };
}

/// Split /500 m en secondes : `temps_total / distance × 500`.
double split500Seconds({
  required double durationS,
  required int distM,
}) {
  if (distM <= 0 || durationS <= 0) return 0;
  return durationS / distM * 500.0;
}

/// Format mm:ss (ou h:mm:ss si ≥ 60 min).
String formatErgTime(double seconds) {
  if (seconds.isNaN || seconds.isInfinite || seconds < 0) return '—';
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Format split m:ss /500 m.
String formatSplit500(double seconds) {
  if (seconds <= 0) return '—';
  return '${formatErgTime(seconds)} /500 m';
}

class FunnelProfile {
  const FunnelProfile({
    required this.frame,
    this.todayDistanceM = 0,
    this.todayDurationMin,
    this.targetSplit500s,
    this.pb2000s,
    this.dragFactor,
    this.onboardDone = false,
  });

  final PracticeFrame frame;
  final int todayDistanceM;
  final int? todayDurationMin;
  final double? targetSplit500s;
  final double? pb2000s;
  final int? dragFactor;
  final bool onboardDone;

  FunnelProfile copyWith({
    PracticeFrame? frame,
    int? todayDistanceM,
    int? todayDurationMin,
    double? targetSplit500s,
    double? pb2000s,
    int? dragFactor,
    bool? onboardDone,
    bool clearTodayDuration = false,
  }) =>
      FunnelProfile(
        frame: frame ?? this.frame,
        todayDistanceM: todayDistanceM ?? this.todayDistanceM,
        todayDurationMin:
            clearTodayDuration ? null : (todayDurationMin ?? this.todayDurationMin),
        targetSplit500s: targetSplit500s ?? this.targetSplit500s,
        pb2000s: pb2000s ?? this.pb2000s,
        dragFactor: dragFactor ?? this.dragFactor,
        onboardDone: onboardDone ?? this.onboardDone,
      );

  Map<String, dynamic> toJson() => {
        'frame': frame.wire,
        'todayDistanceM': todayDistanceM,
        if (todayDurationMin != null) 'todayDurationMin': todayDurationMin,
        if (targetSplit500s != null) 'targetSplit500s': targetSplit500s,
        if (pb2000s != null) 'pb2000s': pb2000s,
        if (dragFactor != null) 'dragFactor': dragFactor,
        'onboardDone': onboardDone,
      };

  static FunnelProfile fromJson(Map<String, dynamic> j) => FunnelProfile(
        frame: PracticeFrame.tryParse(j['frame'] as String?) ?? PracticeFrame.loisir,
        todayDistanceM: (j['todayDistanceM'] as num?)?.toInt() ?? 0,
        todayDurationMin: (j['todayDurationMin'] as num?)?.toInt(),
        targetSplit500s: (j['targetSplit500s'] as num?)?.toDouble(),
        pb2000s: (j['pb2000s'] as num?)?.toDouble(),
        dragFactor: (j['dragFactor'] as num?)?.toInt(),
        onboardDone: j['onboardDone'] == true,
      );

  /// Libellé carte home : distance FFA ou durée loisir/santé.
  String get todayCardLabel {
    if (todayDistanceM > 0) {
      final d = ErgDistance.fromMeters(todayDistanceM);
      return d?.label ?? '$todayDistanceM m';
    }
    if (todayDurationMin != null && todayDurationMin! > 0) {
      return '${todayDurationMin!} min';
    }
    return ErgDistance.m500.label;
  }

  /// Distance effective pour preview Lot 1 (500/2000).
  int get playDistanceM {
    if (todayDistanceM == ErgDistance.m500.meters ||
        todayDistanceM == ErgDistance.m2000.meters) {
      return todayDistanceM;
    }
    // Loisir / santé : carte durée, pièce Lot 1 = 500 m.
    return ErgDistance.m500.meters;
  }
}

class ErgSessionLog {
  const ErgSessionLog({
    required this.distM,
    required this.durationS,
    required this.split500S,
    this.cadence,
    this.watts,
    this.dragFactor,
    required this.complete,
    this.origin = 'indoor',
    required this.at,
  });

  final int distM;
  final double durationS;
  final double split500S;
  final double? cadence;
  final double? watts;
  final int? dragFactor;
  final bool complete;
  final String origin;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'distM': distM,
        'durationS': durationS,
        'split500S': split500S,
        if (cadence != null) 'cadence': cadence,
        if (watts != null) 'watts': watts,
        if (dragFactor != null) 'dragFactor': dragFactor,
        'complete': complete,
        'origin': origin,
        'at': at.toUtc().toIso8601String(),
      };

  static ErgSessionLog fromJson(Map<String, dynamic> j) => ErgSessionLog(
        distM: (j['distM'] as num).toInt(),
        durationS: (j['durationS'] as num).toDouble(),
        split500S: (j['split500S'] as num).toDouble(),
        cadence: (j['cadence'] as num?)?.toDouble(),
        watts: (j['watts'] as num?)?.toDouble(),
        dragFactor: (j['dragFactor'] as num?)?.toInt(),
        complete: j['complete'] == true,
        origin: (j['origin'] as String?) ?? 'indoor',
        at: DateTime.parse(j['at'] as String),
      );
}

/// PB sur une distance : logs complets uniquement.
double? personalBestSeconds(List<ErgSessionLog> logs, int distM) {
  double? best;
  for (final log in logs) {
    if (!log.complete || log.distM != distM) continue;
    if (best == null || log.durationS < best) best = log.durationS;
  }
  return best;
}

bool isPersonalBest({
  required ErgSessionLog log,
  required List<ErgSessionLog> prior,
}) {
  if (!log.complete) return false;
  final best = personalBestSeconds(prior, log.distM);
  if (best == null) return true;
  return log.durationS <= best;
}
