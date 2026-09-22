import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

class LiveClubRemote implements ClubRemote {
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
      final list = data is List ? data : const [];
      if (list.isEmpty) return null;
      final row = Map<String, dynamic>.from(list.first as Map);
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
      final list = data is List ? data : const [];
      if (list.isEmpty) return null;
      final row = Map<String, dynamic>.from(list.first as Map);
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
  Future<void> upsertRower(Map<String, dynamic> row) async {
    final client = supabaseOrNull();
    if (client == null) return;
    try {
      await client.from('rowers').upsert(row);
    } catch (_) {}
  }

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
}

class MemoryClubRemote implements ClubRemote {
  RemoteMembership? membership;
  final clubs = <String, RemoteClub>{};
  final rowers = <Map<String, dynamic>>[];
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
  Future<void> approveJoin(String requestId, {required bool accept}) async {
    approvals[requestId] = accept;
  }
}
