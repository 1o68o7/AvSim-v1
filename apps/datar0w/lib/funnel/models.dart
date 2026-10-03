/// Funnel rameur — Lot 1 (500/2000) + Lot 2 (ateliers brevet + relais 4×500).

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
  m1000(1000),
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
        m1000 => '1 000 m',
        m2000 => '2 000 m',
      };
}

/// Type de morceau Lot 2 (formats FFA nommés — pas une bibliothèque libre).
enum ErgPieceKind {
  /// Distance classique (500 / 1 000 annoncé / 2 000).
  distance,

  /// Durée continue (5 min @ cadence).
  duration,

  /// Blocs intervalle (3 × 1 min @ 18/22/26).
  intervals,

  /// Relais championnats (4 × 500 m).
  relay;

  String get wire => name;

  static ErgPieceKind? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

/// Catalogue atelier / pièce officielle.
class ErgPiece {
  const ErgPiece({
    required this.id,
    required this.kind,
    required this.label,
    required this.cues,
    this.distM,
    this.durationS,
    this.targetCadence,
    this.blockCadences = const [],
    this.blockCount = 1,
    this.blockDistM,
    this.announcedMinM,
    this.announcedMaxM,
    this.kpiHint = '',
  });

  final String id;
  final ErgPieceKind kind;
  final String label;
  final List<String> cues;
  final int? distM;
  final int? durationS;
  final int? targetCadence;
  final List<int> blockCadences;
  final int blockCount;
  final int? blockDistM;
  final int? announcedMinM;
  final int? announcedMaxM;
  final String kpiHint;

  /// Distance « logique » pour logs / brief count (relais = total).
  int get logDistM {
    if (kind == ErgPieceKind.relay) {
      return (blockDistM ?? 500) * blockCount;
    }
    if (kind == ErgPieceKind.duration || kind == ErgPieceKind.intervals) {
      return 0;
    }
    return distM ?? 0;
  }

  String get cardLabel => label;

  static const fiveMin18 = ErgPiece(
    id: 'brevet_5min_18',
    kind: ErgPieceKind.duration,
    label: '5 min continu',
    cues: [
      'Cadence 18',
      'Longueur de coup',
      'Split en secondaire',
    ],
    durationS: 5 * 60,
    targetCadence: 18,
    kpiHint: 'cadence · split',
  );

  static const threeByOne = ErgPiece(
    id: 'brevet_3x1min',
    kind: ErgPieceKind.intervals,
    label: '3 × 1 min',
    cues: [
      'Bloc 1 · cadence 18',
      'Bloc 2 · cadence 22',
      'Bloc 3 · cadence 26',
    ],
    durationS: 60,
    blockCount: 3,
    blockCadences: [18, 22, 26],
    kpiHint: 'cadence par bloc',
  );

  static const announced1000 = ErgPiece(
    id: 'brevet_1000_annonce',
    kind: ErgPieceKind.distance,
    label: '1 000 m annoncé',
    cues: [
      'Temps annoncé',
      'Réalisé entre 990 et 1 010 m',
      'Pas un 1 000 m libre',
    ],
    distM: 1000,
    announcedMinM: 990,
    announcedMaxM: 1010,
    kpiHint: 'distance vs temps',
  );

  static const relay4x500 = ErgPiece(
    id: 'relay_4x500',
    kind: ErgPieceKind.relay,
    label: 'Relais 4 × 500 m',
    cues: [
      'Championnats FFA',
      'Quatre jambes de 500 m',
      'Temps et split par jambe',
    ],
    blockCount: 4,
    blockDistM: 500,
    kpiHint: 'temps · split',
  );

  static const distance500 = ErgPiece(
    id: 'dist_500',
    kind: ErgPieceKind.distance,
    label: '500 m',
    cues: ['Départ propre', 'Cadence stable', 'Split affiché'],
    distM: 500,
    kpiHint: 'temps · split',
  );

  static const distance2000 = ErgPiece(
    id: 'dist_2000',
    kind: ErgPieceKind.distance,
    label: '2 000 m',
    cues: [
      '0–500 m · installation',
      '500–1 500 m · tenu',
      '1 500–2 000 m · cadence +2',
    ],
    distM: 2000,
    kpiHint: 'temps · split · watts',
  );

  /// Lot 2 — ateliers brevet + relais (écran DR-FR-A).
  static const lot2Catalog = [
    fiveMin18,
    threeByOne,
    announced1000,
    relay4x500,
  ];

  static ErgPiece? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final p in [
      ...lot2Catalog,
      distance500,
      distance2000,
    ]) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Pièce Lot 1 à partir d’une distance FFA.
  static ErgPiece fromDistanceMeters(int meters) {
    if (meters == ErgDistance.m2000.meters) return distance2000;
    if (meters == ErgDistance.m1000.meters) return announced1000;
    return distance500;
  }
}

/// 1 000 m annoncé : distance réalisée dans [990, 1010].
bool announced1000InBand(int realizedM) =>
    realizedM >= 990 && realizedM <= 1010;

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
    this.todayPieceId,
    this.targetSplit500s,
    this.pb2000s,
    this.dragFactor,
    this.onboardDone = false,
  });

  final PracticeFrame frame;
  final int todayDistanceM;
  final int? todayDurationMin;
  final String? todayPieceId;
  final double? targetSplit500s;
  final double? pb2000s;
  final int? dragFactor;
  final bool onboardDone;

  FunnelProfile copyWith({
    PracticeFrame? frame,
    int? todayDistanceM,
    int? todayDurationMin,
    String? todayPieceId,
    double? targetSplit500s,
    double? pb2000s,
    int? dragFactor,
    bool? onboardDone,
    bool clearTodayDuration = false,
    bool clearTodayPiece = false,
  }) =>
      FunnelProfile(
        frame: frame ?? this.frame,
        todayDistanceM: todayDistanceM ?? this.todayDistanceM,
        todayDurationMin:
            clearTodayDuration ? null : (todayDurationMin ?? this.todayDurationMin),
        todayPieceId:
            clearTodayPiece ? null : (todayPieceId ?? this.todayPieceId),
        targetSplit500s: targetSplit500s ?? this.targetSplit500s,
        pb2000s: pb2000s ?? this.pb2000s,
        dragFactor: dragFactor ?? this.dragFactor,
        onboardDone: onboardDone ?? this.onboardDone,
      );

  Map<String, dynamic> toJson() => {
        'frame': frame.wire,
        'todayDistanceM': todayDistanceM,
        if (todayDurationMin != null) 'todayDurationMin': todayDurationMin,
        if (todayPieceId != null) 'todayPieceId': todayPieceId,
        if (targetSplit500s != null) 'targetSplit500s': targetSplit500s,
        if (pb2000s != null) 'pb2000s': pb2000s,
        if (dragFactor != null) 'dragFactor': dragFactor,
        'onboardDone': onboardDone,
      };

  static FunnelProfile fromJson(Map<String, dynamic> j) => FunnelProfile(
        frame: PracticeFrame.tryParse(j['frame'] as String?) ?? PracticeFrame.loisir,
        todayDistanceM: (j['todayDistanceM'] as num?)?.toInt() ?? 0,
        todayDurationMin: (j['todayDurationMin'] as num?)?.toInt(),
        todayPieceId: j['todayPieceId'] as String?,
        targetSplit500s: (j['targetSplit500s'] as num?)?.toDouble(),
        pb2000s: (j['pb2000s'] as num?)?.toDouble(),
        dragFactor: (j['dragFactor'] as num?)?.toInt(),
        onboardDone: j['onboardDone'] == true,
      );

  ErgPiece get todayPiece {
    final named = ErgPiece.byId(todayPieceId);
    if (named != null) return named;
    if (todayDistanceM > 0) return ErgPiece.fromDistanceMeters(todayDistanceM);
    return ErgPiece.distance500;
  }

  /// Libellé carte home : pièce nommée, distance FFA ou durée loisir/santé.
  String get todayCardLabel {
    if (todayPieceId != null) {
      final p = ErgPiece.byId(todayPieceId);
      if (p != null) return p.label;
    }
    if (todayDistanceM > 0) {
      final d = ErgDistance.fromMeters(todayDistanceM);
      return d?.label ?? '$todayDistanceM m';
    }
    if (todayDurationMin != null && todayDurationMin! > 0) {
      return '${todayDurationMin!} min';
    }
    return ErgDistance.m500.label;
  }

  /// Distance effective Lot 1 (500/2000) si pas de pièce durée/intervalle.
  int get playDistanceM {
    final piece = todayPiece;
    if (piece.kind == ErgPieceKind.distance || piece.kind == ErgPieceKind.relay) {
      return piece.logDistM > 0 ? piece.logDistM : ErgDistance.m500.meters;
    }
    if (todayDistanceM == ErgDistance.m500.meters ||
        todayDistanceM == ErgDistance.m2000.meters ||
        todayDistanceM == ErgDistance.m1000.meters) {
      return todayDistanceM;
    }
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
    this.pieceId,
    this.realizedDistM,
    this.blockCadences = const [],
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
  final String? pieceId;
  /// Distance réalisée (1 000 m annoncé : 990–1 010).
  final int? realizedDistM;
  final List<int> blockCadences;
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
        if (pieceId != null) 'pieceId': pieceId,
        if (realizedDistM != null) 'realizedDistM': realizedDistM,
        if (blockCadences.isNotEmpty) 'blockCadences': blockCadences,
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
        pieceId: j['pieceId'] as String?,
        realizedDistM: (j['realizedDistM'] as num?)?.toInt(),
        blockCadences: (j['blockCadences'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [],
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
  // Ateliers durée / intervalles : pas de PB distance.
  if (log.distM <= 0) return false;
  final best = personalBestSeconds(prior, log.distM);
  if (best == null) return true;
  return log.durationS <= best;
}
