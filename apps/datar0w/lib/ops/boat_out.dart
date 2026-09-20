import '../identity/id.dart';

enum BoatOutStatus { reserved, out, returned }

extension BoatOutStatusX on BoatOutStatus {
  String get wire => name;

  static BoatOutStatus parse(String? raw) {
    switch (raw) {
      case 'reserved':
        return BoatOutStatus.reserved;
      case 'returned':
        return BoatOutStatus.returned;
      default:
        return BoatOutStatus.out;
    }
  }
}

/// Sortie de parc explicite (≠ composition).
class BoatOut {
  const BoatOut({
    required this.id,
    required this.boatId,
    required this.coachId,
    required this.startedAt,
    this.plannedEnd,
    this.endedAt,
    required this.status,
    this.oarSetId,
    this.crewFrozen = true,
    this.transferredFromCoachId,
    this.transferredAt,
    this.oarsOk,
    this.oarsMissingNote,
  });

  final String id;
  final String boatId;
  final String coachId;
  final DateTime startedAt;
  final DateTime? plannedEnd;
  final DateTime? endedAt;
  final BoatOutStatus status;
  final String? oarSetId;
  final bool crewFrozen;
  final String? transferredFromCoachId;
  final DateTime? transferredAt;
  final bool? oarsOk;
  final String? oarsMissingNote;

  bool get isActive =>
      status == BoatOutStatus.out || status == BoatOutStatus.reserved;

  BoatOut copyWith({
    String? coachId,
    DateTime? plannedEnd,
    DateTime? endedAt,
    bool clearEnded = false,
    BoatOutStatus? status,
    String? oarSetId,
    bool? crewFrozen,
    String? transferredFromCoachId,
    DateTime? transferredAt,
    bool? oarsOk,
    String? oarsMissingNote,
  }) {
    return BoatOut(
      id: id,
      boatId: boatId,
      coachId: coachId ?? this.coachId,
      startedAt: startedAt,
      plannedEnd: plannedEnd ?? this.plannedEnd,
      endedAt: clearEnded ? null : (endedAt ?? this.endedAt),
      status: status ?? this.status,
      oarSetId: oarSetId ?? this.oarSetId,
      crewFrozen: crewFrozen ?? this.crewFrozen,
      transferredFromCoachId:
          transferredFromCoachId ?? this.transferredFromCoachId,
      transferredAt: transferredAt ?? this.transferredAt,
      oarsOk: oarsOk ?? this.oarsOk,
      oarsMissingNote: oarsMissingNote ?? this.oarsMissingNote,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'boatId': boatId,
        'coachId': coachId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'plannedEnd': plannedEnd?.toUtc().toIso8601String(),
        'endedAt': endedAt?.toUtc().toIso8601String(),
        'status': status.wire,
        'oarSetId': oarSetId,
        'crewFrozen': crewFrozen,
        'transferredFromCoachId': transferredFromCoachId,
        'transferredAt': transferredAt?.toUtc().toIso8601String(),
        'oarsOk': oarsOk,
        'oarsMissingNote': oarsMissingNote,
      };

  static BoatOut fromJson(Map<String, dynamic> j) => BoatOut(
        id: j['id'] as String,
        boatId: j['boatId'] as String,
        coachId: j['coachId'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        plannedEnd: j['plannedEnd'] is String
            ? DateTime.parse(j['plannedEnd'] as String)
            : null,
        endedAt: j['endedAt'] is String
            ? DateTime.parse(j['endedAt'] as String)
            : null,
        status: BoatOutStatusX.parse(j['status'] as String?),
        oarSetId: j['oarSetId'] as String?,
        crewFrozen: j['crewFrozen'] as bool? ?? true,
        transferredFromCoachId: j['transferredFromCoachId'] as String?,
        transferredAt: j['transferredAt'] is String
            ? DateTime.parse(j['transferredAt'] as String)
            : null,
        oarsOk: j['oarsOk'] as bool?,
        oarsMissingNote: j['oarsMissingNote'] as String?,
      );

  static BoatOut create({
    required String boatId,
    required String coachId,
    DateTime? startedAt,
    DateTime? plannedEnd,
    BoatOutStatus status = BoatOutStatus.reserved,
    String? oarSetId,
  }) {
    return BoatOut(
      id: newIdentityId(),
      boatId: boatId,
      coachId: coachId,
      startedAt: startedAt ?? DateTime.now().toUtc(),
      plannedEnd: plannedEnd,
      status: status,
      oarSetId: oarSetId,
    );
  }
}

class QueueEntry {
  const QueueEntry({
    required this.id,
    required this.boatId,
    required this.coachId,
    required this.requestedAt,
    required this.message,
  });

  final String id;
  final String boatId;
  final String coachId;
  final DateTime requestedAt;
  final String message;

  Map<String, dynamic> toJson() => {
        'id': id,
        'boatId': boatId,
        'coachId': coachId,
        'requestedAt': requestedAt.toUtc().toIso8601String(),
        'message': message,
      };

  static QueueEntry fromJson(Map<String, dynamic> j) => QueueEntry(
        id: j['id'] as String,
        boatId: j['boatId'] as String,
        coachId: j['coachId'] as String,
        requestedAt: DateTime.parse(j['requestedAt'] as String),
        message: j['message'] as String? ?? '',
      );

  static QueueEntry create({
    required String boatId,
    required String coachId,
    required String message,
  }) {
    return QueueEntry(
      id: newIdentityId(),
      boatId: boatId,
      coachId: coachId,
      requestedAt: DateTime.now().toUtc(),
      message: message,
    );
  }
}
