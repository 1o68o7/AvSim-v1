import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/models.dart';
import 'club_sql.dart';
import 'supabase_boot.dart';

final clubRemoteProvider = Provider<ClubRemote>((ref) => LiveClubRemote());

class RemoteClub {
  const RemoteClub({
    required this.id,
    required this.name,
    this.shortCode,
  });

  final String id;
  final String name;
  final String? shortCode;
}

class RemoteMembership {
  const RemoteMembership({
    required this.clubId,
    required this.role,
    this.rowerId,
  });

  final String clubId;
  final String role;
  final String? rowerId;
}

class RemotePark {
  const RemotePark({
    this.boats = const [],
    this.rowers = const [],
    this.assignments = const [],
  });

  final List<ParkBoat> boats;
  final List<Rower> rowers;
  final List<Assignment> assignments;
}

/// Miroir master-data club. No-op sans session / sans clés. Pas l’outbox #50.
abstract class ClubRemote {
  Future<RemoteMembership?> membershipFor(String userId);
  Future<RemoteClub?> clubById(String id);
  Future<void> insertClub({
    required String id,
    required String name,
    String? shortCode,
  });
  Future<void> upsertRower(Map<String, dynamic> row);
  Future<void> approveJoin(String requestId, {required bool accept});
  Future<void> upsertBoat(Map<String, dynamic> row);
  Future<void> upsertAssignment(Map<String, dynamic> row);
  Future<RemotePark> parkForClub(String clubId);
}

class SilentClubRemote implements ClubRemote {
  const SilentClubRemote();

  @override
  Future<RemoteMembership?> membershipFor(String userId) async => null;

  @override
  Future<RemoteClub?> clubById(String id) async => null;

  @override
  Future<void> insertClub({
    required String id,
    required String name,
    String? shortCode,
  }) async {}

  @override
  Future<void> upsertRower(Map<String, dynamic> row) async {}

  @override
  Future<void> approveJoin(String requestId, {required bool accept}) async {}

  @override
  Future<void> upsertBoat(Map<String, dynamic> row) async {}

  @override
  Future<void> upsertAssignment(Map<String, dynamic> row) async {}

  @override
  Future<RemotePark> parkForClub(String clubId) async => const RemotePark();
}

class LiveClubRemote implements ClubRemote {
  Future<void> _upsert(String table, Map<String, dynamic> row) async {
    final client = supabaseOrNull();
    if (client == null) return;
    try {
      await client.from(table).upsert(row);
    } catch (_) {}
  }

  @override
  Future<RemoteMembership?> membershipFor(String userId) async {
    final client = supabaseOrNull();
    if (client == null) return null;
    try {
      final data = await client
          .from('club_members')
          .select('club_id, role, rower_id')
          .eq('user_id', userId)
          .limit(1);
      final list = asRowList(data);
      if (list.isEmpty) return null;
      final row = list.first;
      final clubId = row['club_id'] as String?;
      if (clubId == null) return null;
      return RemoteMembership(
        clubId: clubId,
        role: row['role'] as String? ?? 'rower',
        rowerId: row['rower_id'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RemoteClub?> clubById(String id) async {
    final client = supabaseOrNull();
    if (client == null) return null;
    try {
      final data = await client
          .from('clubs')
          .select('id, name, short_code')
          .eq('id', id)
          .limit(1);
      final list = asRowList(data);
      if (list.isEmpty) return null;
      final row = list.first;
      return RemoteClub(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        shortCode: row['short_code'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> insertClub({
    required String id,
    required String name,
    String? shortCode,
  }) async {
    final client = supabaseOrNull();
    if (client == null) return;
    try {
      await client.from('clubs').insert({
        'id': id,
        'name': name,
        'short_code': shortCode,
      });
    } catch (_) {}
  }

  @override
  Future<void> upsertRower(Map<String, dynamic> row) => _upsert('rowers', row);

  @override
  Future<void> upsertBoat(Map<String, dynamic> row) => _upsert('boats', row);

  @override
  Future<void> upsertAssignment(Map<String, dynamic> row) =>
      _upsert('assignments', row);

  @override
  Future<void> approveJoin(String requestId, {required bool accept}) async {
    final client = supabaseOrNull();
    if (client == null) return;
    try {
      await client.rpc(
        'approve_join_request',
        params: {'p_id': requestId, 'p_accept': accept},
      );
    } catch (_) {}
  }

  @override
  Future<RemotePark> parkForClub(String clubId) async {
    final client = supabaseOrNull();
    if (client == null) return const RemotePark();
    try {
      final boats = asRowList(
        await client.from('boats').select().eq('club_id', clubId),
      );
      final rowers = asRowList(
        await client.from('rowers').select().eq('club_id', clubId),
      );
      final assignments = asRowList(
        await client.from('assignments').select().eq('club_id', clubId),
      );
      return RemotePark(
        boats: [for (final r in boats) ?boatFromSql(r)],
        rowers: [for (final r in rowers) ?rowerFromSql(r)],
        assignments: [for (final r in assignments) ?assignmentFromSql(r)],
      );
    } catch (_) {
      return const RemotePark();
    }
  }
}

class MemoryClubRemote implements ClubRemote {
  RemoteMembership? membership;
  final clubs = <String, RemoteClub>{};
  final rowers = <Map<String, dynamic>>[];
  final boats = <Map<String, dynamic>>[];
  final assignments = <Map<String, dynamic>>[];
  RemotePark park = const RemotePark();
  final approvals = <String, bool>{};
  int insertClubCalls = 0;

  @override
  Future<RemoteMembership?> membershipFor(String userId) async => membership;

  @override
  Future<RemoteClub?> clubById(String id) async => clubs[id];

  @override
  Future<void> insertClub({
    required String id,
    required String name,
    String? shortCode,
  }) async {
    insertClubCalls++;
    clubs[id] = RemoteClub(id: id, name: name, shortCode: shortCode);
  }

  @override
  Future<void> upsertRower(Map<String, dynamic> row) async {
    rowers.add(row);
  }

  @override
  Future<void> upsertBoat(Map<String, dynamic> row) async {
    boats.add(row);
  }

  @override
  Future<void> upsertAssignment(Map<String, dynamic> row) async {
    assignments.add(row);
  }

  @override
  Future<void> approveJoin(String requestId, {required bool accept}) async {
    approvals[requestId] = accept;
  }

  @override
  Future<RemotePark> parkForClub(String clubId) async => park;
}
