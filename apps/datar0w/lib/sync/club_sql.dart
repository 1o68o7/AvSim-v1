import '../identity/models.dart';

String sqlBoatStatus(BoatParkStatus s) => switch (s) {
      BoatParkStatus.maintenance => 'maintenance',
      BoatParkStatus.ready => 'ready',
      _ => 'out',
    };

Map<String, dynamic> boatToSql(ParkBoat b) => {
      'id': b.id,
      'club_id': b.clubId,
      'name': b.name,
      'class': b.classe,
      'seats': b.seats,
      'cox': b.cox,
      'oar_rack': b.oarRack,
      'status': sqlBoatStatus(b.status),
    };

Map<String, dynamic> assignmentToSql(Assignment a, String clubId) => {
      'id': a.id,
      'club_id': clubId,
      'boat_id': a.boatId,
      'rower_id': a.rowerId,
      'seat_index': a.seatIndex,
      'side': a.side == SidePref.none ? null : a.side.wire,
      'oars': a.oars,
      'role': a.role == 'cox' ? 'cox' : 'rower',
      'cox_position': a.coxPosition,
    };

Map<String, dynamic> rowerToSql(Rower r) => {
      'id': r.id,
      'club_id': r.clubId,
      'user_id': r.userId,
      'display_name': r.displayName,
      'birth_date': r.birthDate.toUtc().toIso8601String().split('T').first,
      'sex': r.sex.wire,
    };

ParkBoat? boatFromSql(Map<String, dynamic> j) {
  final id = j['id'] as String?;
  final clubId = j['club_id'] as String?;
  if (id == null || clubId == null) return null;
  return ParkBoat.fromJson({
    'id': id,
    'clubId': clubId,
    'name': j['name'],
    'class': j['class'],
    'seats': j['seats'],
    'cox': j['cox'],
    'oarRack': j['oar_rack'] ?? j['oarRack'],
    'status': j['status'],
  });
}

Rower? rowerFromSql(Map<String, dynamic> j) {
  final id = j['id'] as String?;
  final name = j['display_name'] as String?;
  final birth = j['birth_date'] as String?;
  if (id == null || name == null || birth == null) return null;
  final now = DateTime.now().toUtc();
  return Rower(
    id: id,
    displayName: name,
    birthDate: DateTime.parse(birth),
    sex: RowerSexX.parse(j['sex'] as String?),
    clubId: j['club_id'] as String?,
    userId: j['user_id'] as String?,
    createdAt: now,
    updatedAt: now,
  );
}

Assignment? assignmentFromSql(Map<String, dynamic> j) {
  final id = j['id'] as String?;
  final boatId = j['boat_id'] as String?;
  final rowerId = j['rower_id'] as String?;
  if (id == null || boatId == null || rowerId == null) return null;
  return Assignment(
    id: id,
    boatId: boatId,
    seatIndex: (j['seat_index'] as num?)?.toInt(),
    rowerId: rowerId,
    side: SidePrefX.parse(j['side'] as String?),
    oars: (j['oars'] as List?)?.map((e) => '$e').toList() ?? const [],
    role: j['role'] as String? ?? 'rower',
    coxPosition: j['cox_position'] as String?,
    createdAt: DateTime.now().toUtc(),
  );
}

List<Map<String, dynamic>> asRowList(dynamic data) {
  if (data is! List) return const [];
  return [
    for (final e in data)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}
