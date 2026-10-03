import '../identity/models.dart';
import 'models.dart';

/// Créneau de dispo (expire en fin de jour local).
enum DispoSlot { matin, midi, soir }

extension DispoSlotX on DispoSlot {
  String get wire => name;
  String get label => switch (this) {
        DispoSlot.matin => 'Matin',
        DispoSlot.midi => 'Midi',
        DispoSlot.soir => 'Soir',
      };

  static DispoSlot? tryParse(String? raw) {
    for (final v in DispoSlot.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

enum DispoMode { eau, erg, lesDeux }

extension DispoModeX on DispoMode {
  String get wire => name;
  String get label => switch (this) {
        DispoMode.eau => 'Eau',
        DispoMode.erg => 'Erg',
        DispoMode.lesDeux => 'Les deux',
      };

  static DispoMode? tryParse(String? raw) {
    for (final v in DispoMode.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

class RowerDispo {
  const RowerDispo({
    required this.rowerId,
    required this.day,
    required this.slot,
    required this.mode,
  });

  final String rowerId;
  /// Jour local yyyy-mm-dd.
  final String day;
  final DispoSlot slot;
  final DispoMode mode;

  Map<String, dynamic> toJson() => {
        'rowerId': rowerId,
        'day': day,
        'slot': slot.wire,
        'mode': mode.wire,
      };

  static RowerDispo fromJson(Map<String, dynamic> j) => RowerDispo(
        rowerId: j['rowerId'] as String,
        day: j['day'] as String,
        slot: DispoSlotX.tryParse(j['slot'] as String?) ?? DispoSlot.soir,
        mode: DispoModeX.tryParse(j['mode'] as String?) ?? DispoMode.lesDeux,
      );
}

/// Motifs veto coach (porte plan d’eau).
enum WaterVetoReason {
  vent,
  orage,
  crue,
  glace,
  brouillard,
  navigation,
  autre,
}

extension WaterVetoReasonX on WaterVetoReason {
  String get wire => name;
  String get label => switch (this) {
        WaterVetoReason.vent => 'Vent',
        WaterVetoReason.orage => 'Orage',
        WaterVetoReason.crue => 'Crue',
        WaterVetoReason.glace => 'Glace',
        WaterVetoReason.brouillard => 'Brouillard',
        WaterVetoReason.navigation => 'Navigation',
        WaterVetoReason.autre => 'Autre',
      };

  static WaterVetoReason? tryParse(String? raw) {
    for (final v in WaterVetoReason.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

class WaterClosure {
  const WaterClosure({
    required this.id,
    required this.waterId,
    required this.from,
    required this.to,
    required this.reason,
    this.note,
  });

  final String id;
  final String waterId;
  final DateTime from;
  final DateTime to;
  final WaterVetoReason reason;
  final String? note;

  bool activeAt(DateTime t) => !t.isBefore(from) && t.isBefore(to);

  String get reasonLine {
    final base = '${reason.label} · veto coach';
    if (note == null || note!.trim().isEmpty) return base;
    return '$base · ${note!.trim()}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'waterId': waterId,
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'reason': reason.wire,
        if (note != null) 'note': note,
      };

  static WaterClosure fromJson(Map<String, dynamic> j) => WaterClosure(
        id: j['id'] as String,
        waterId: j['waterId'] as String,
        from: DateTime.parse(j['from'] as String),
        to: DateTime.parse(j['to'] as String),
        reason:
            WaterVetoReasonX.tryParse(j['reason'] as String?) ??
                WaterVetoReason.autre,
        note: j['note'] as String?,
      );
}

enum SeatConfirmState { confirmed, pending, absent, replaced }

extension SeatConfirmStateX on SeatConfirmState {
  String get wire => name;
  static SeatConfirmState parse(String? raw) {
    for (final v in SeatConfirmState.values) {
      if (v.name == raw) return v;
    }
    return SeatConfirmState.pending;
  }
}

/// Sortie eau prévue (local).
class WaterOutingPlan {
  const WaterOutingPlan({
    required this.id,
    required this.boatId,
    required this.boatClass,
    required this.plannedAt,
    required this.distM,
    required this.waterId,
    this.waterLabel = 'Plan d’eau',
    this.seatsRequired = 4,
    this.coxRequired = false,
    this.seatStates = const {},
  });

  final String id;
  final String boatId;
  final String boatClass;
  final DateTime plannedAt;
  final int distM;
  final String waterId;
  final String waterLabel;
  final int seatsRequired;
  final bool coxRequired;
  final Map<String, SeatConfirmState> seatStates; // rowerId → state

  String get timeLabel {
    final l = plannedAt.toLocal();
    final h = l.hour.toString().padLeft(2, '0');
    final m = l.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get headline {
    final dist = ErgDistance.fromMeters(distM)?.label ?? '$distM m';
    return '$timeLabel · $boatClass · $dist';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'boatId': boatId,
        'boatClass': boatClass,
        'plannedAt': plannedAt.toUtc().toIso8601String(),
        'distM': distM,
        'waterId': waterId,
        'waterLabel': waterLabel,
        'seatsRequired': seatsRequired,
        'coxRequired': coxRequired,
        'seatStates': seatStates.map((k, v) => MapEntry(k, v.wire)),
      };

  static WaterOutingPlan fromJson(Map<String, dynamic> j) {
    final raw = j['seatStates'];
    final seats = <String, SeatConfirmState>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        seats['${e.key}'] = SeatConfirmStateX.parse('${e.value}');
      }
    }
    return WaterOutingPlan(
      id: j['id'] as String,
      boatId: j['boatId'] as String,
      boatClass: j['boatClass'] as String? ?? '4x',
      plannedAt: DateTime.parse(j['plannedAt'] as String),
      distM: (j['distM'] as num?)?.toInt() ?? 2000,
      waterId: j['waterId'] as String? ?? 'local',
      waterLabel: j['waterLabel'] as String? ?? 'Plan d’eau',
      seatsRequired: (j['seatsRequired'] as num?)?.toInt() ?? 4,
      coxRequired: j['coxRequired'] == true,
      seatStates: seats,
    );
  }

  WaterOutingPlan copyWith({
    Map<String, SeatConfirmState>? seatStates,
  }) =>
      WaterOutingPlan(
        id: id,
        boatId: boatId,
        boatClass: boatClass,
        plannedAt: plannedAt,
        distM: distM,
        waterId: waterId,
        waterLabel: waterLabel,
        seatsRequired: seatsRequired,
        coxRequired: coxRequired,
        seatStates: seatStates ?? this.seatStates,
      );
}

enum WaterGateKind { open, crewBroken, waterClosed, rowerChoseErg }

class WaterGateResult {
  const WaterGateResult({
    required this.kind,
    this.crewConfirmed = 0,
    this.crewNeeded = 0,
    this.waterReason,
    this.canDownsize = false,
  });

  final WaterGateKind kind;
  final int crewConfirmed;
  final int crewNeeded;
  final String? waterReason;
  final bool canDownsize;

  bool get boatAllowed => kind == WaterGateKind.open;
}

String localDayKey([DateTime? now]) {
  final l = (now ?? DateTime.now()).toLocal();
  return '${l.year.toString().padLeft(4, '0')}-'
      '${l.month.toString().padLeft(2, '0')}-'
      '${l.day.toString().padLeft(2, '0')}';
}

/// Mapping séance eau → pièce erg (plafonds déjà posés).
ErgPiece ergReplacementForWater({
  required int waterDistM,
  required PracticeFrame frame,
}) {
  if (frame == PracticeFrame.loisir || frame == PracticeFrame.sante) {
    if (waterDistM >= 6000) {
      return const ErgPiece(
        id: 'duration_30',
        kind: ErgPieceKind.duration,
        label: '30 min',
        cues: ['Loisir / santé', 'Pas de 2 000 m imposé', 'Split secondaire'],
        durationS: 30 * 60,
        kpiHint: 'temps · cadence',
      );
    }
    return const ErgPiece(
      id: 'duration_15',
      kind: ErgPieceKind.duration,
      label: '15 min',
      cues: ['Loisir / santé', 'Pas de 2 000 m imposé', 'Split secondaire'],
      durationS: 15 * 60,
      kpiHint: 'temps · cadence',
    );
  }
  return ErgPiece.fromDistanceMeters(waterDistM);
}
