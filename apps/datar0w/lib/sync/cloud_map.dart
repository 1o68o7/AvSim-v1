import '../identity/models.dart';

Map<String, dynamic> clubToCloud(Club c) => {
      'id': c.id,
      'name': c.name,
      'short_code': c.shortCode,
      'created_at': c.createdAt.toUtc().toIso8601String(),
      'updated_at': c.updatedAt.toUtc().toIso8601String(),
    };

Map<String, dynamic> rowerToCloud(Rower r) => {
      'id': r.id,
      'club_id': r.clubId,
      'user_id': r.userId,
      'display_name': r.displayName,
      'birth_date': r.birthDate.toUtc().toIso8601String().split('T').first,
      'sex': r.sex.wire,
      'weight_kg': r.weightKg,
      'height_cm': r.heightCm,
      'side_pref': r.sidePref.wire,
      'oar_spec': r.oarSpec,
      'level': r.level.wire,
      'created_at': r.createdAt.toUtc().toIso8601String(),
      'updated_at': r.updatedAt.toUtc().toIso8601String(),
    };

Map<String, dynamic> boatToCloud(ParkBoat b) => {
      'id': b.id,
      'club_id': b.clubId,
      'name': b.name,
      'class': b.classe,
      'seats': b.seats,
      'cox': b.cox,
      'oar_rack': b.oarRack,
      'status': b.status.wire,
      'updated_at': b.updatedAt.toUtc().toIso8601String(),
    };

Map<String, dynamic> assignmentToCloud(Assignment a, {required String clubId}) =>
    {
      'id': a.id,
      'club_id': clubId,
      'boat_id': a.boatId,
      'rower_id': a.rowerId,
      'seat_index': a.seatIndex,
      'side': a.side == SidePref.none ? null : a.side.wire,
      'oars': a.oars,
      'role': a.role,
      'cox_position': a.coxPosition,
      'created_at': a.createdAt.toUtc().toIso8601String(),
      'updated_at': a.updatedAt.toUtc().toIso8601String(),
    };

DateTime parseTs(Object? raw, DateTime fallback) {
  if (raw is String && raw.isNotEmpty) return DateTime.parse(raw);
  return fallback;
}

Club clubFromCloud(Map<String, dynamic> j) {
  final created = parseTs(j['created_at'] ?? j['createdAt'], DateTime.now().toUtc());
  return Club(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    shortCode: (j['short_code'] ?? j['shortCode']) as String?,
    createdAt: created,
    updatedAt: parseTs(j['updated_at'] ?? j['updatedAt'], created),
  );
}

Rower rowerFromCloud(Map<String, dynamic> j) {
  final created = parseTs(j['created_at'] ?? j['createdAt'], DateTime.now().toUtc());
  return Rower(
    id: j['id'] as String,
    displayName: (j['display_name'] ?? j['displayName']) as String? ?? '',
    birthDate: DateTime.parse((j['birth_date'] ?? j['birthDate']) as String),
    sex: RowerSexX.parse(j['sex'] as String?),
    weightKg: ((j['weight_kg'] ?? j['weightKg']) as num?)?.toDouble(),
    heightCm: ((j['height_cm'] ?? j['heightCm']) as num?)?.toDouble(),
    sidePref: SidePrefX.parse((j['side_pref'] ?? j['sidePref']) as String?),
    oarSpec: (j['oar_spec'] ?? j['oarSpec']) as String?,
    level: RowerLevelX.parse((j['level'] as String?)),
    clubId: (j['club_id'] ?? j['clubId']) as String?,
    userId: (j['user_id'] ?? j['userId']) as String?,
    createdAt: created,
    updatedAt: parseTs(j['updated_at'] ?? j['updatedAt'], created),
  );
}

ParkBoat boatFromCloud(Map<String, dynamic> j) => ParkBoat.fromJson({
      'id': j['id'],
      'clubId': j['club_id'] ?? j['clubId'],
      'name': j['name'],
      'class': j['class'],
      'seats': j['seats'],
      'cox': j['cox'],
      'oarRack': j['oar_rack'] ?? j['oarRack'],
      'status': j['status'],
      'updatedAt': j['updated_at'] ?? j['updatedAt'],
    });

Assignment assignmentFromCloud(Map<String, dynamic> j) => Assignment.fromJson({
      'id': j['id'],
      'boatId': j['boat_id'] ?? j['boatId'],
      'seatIndex': j['seat_index'] ?? j['seatIndex'],
      'rowerId': j['rower_id'] ?? j['rowerId'],
      'side': j['side'],
      'oars': j['oars'],
      'role': j['role'],
      'coxPosition': j['cox_position'] ?? j['coxPosition'],
      'createdAt': j['created_at'] ?? j['createdAt'],
      'updatedAt': j['updated_at'] ?? j['updatedAt'],
    });
