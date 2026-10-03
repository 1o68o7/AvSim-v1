import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../funnel/lot5_models.dart';
import 'supabase_boot.dart';

final waterRemoteProvider = Provider<WaterRemote>((ref) => LiveWaterRemote());

/// Miroir `water_closures` (+ lecture waters). Pas de table dispos cloud.
abstract class WaterRemote {
  Future<void> upsertClosure(WaterClosure c, {String? clubId, String? createdBy});
  Future<void> deleteClosure(String id);
  Future<List<WaterClosure>> listClosuresForClub(String clubId);
}

class SilentWaterRemote implements WaterRemote {
  const SilentWaterRemote();

  @override
  Future<void> upsertClosure(
    WaterClosure c, {
    String? clubId,
    String? createdBy,
  }) async {}

  @override
  Future<void> deleteClosure(String id) async {}

  @override
  Future<List<WaterClosure>> listClosuresForClub(String clubId) async =>
      const [];
}

class LiveWaterRemote implements WaterRemote {
  @override
  Future<void> upsertClosure(
    WaterClosure c, {
    String? clubId,
    String? createdBy,
  }) async {
    final client = supabaseOrNull();
    if (client == null) return;
    try {
      await client.from('water_closures').upsert({
        'id': c.id,
        'water_id': c.waterId,
        'starts_at': c.from.toUtc().toIso8601String(),
        'ends_at': c.to.toUtc().toIso8601String(),
        'reason': c.reason.wire,
        if (c.note != null) 'note': c.note,
        if (clubId != null) 'club_id': clubId,
        if (createdBy != null) 'created_by': createdBy,
      });
    } catch (e) {
      debugPrint('water_closures upsert FAIL: $e');
    }
  }

  @override
  Future<void> deleteClosure(String id) async {
    final client = supabaseOrNull();
    if (client == null) return;
    try {
      await client.from('water_closures').delete().eq('id', id);
    } catch (e) {
      debugPrint('water_closures delete FAIL: $e');
    }
  }

  @override
  Future<List<WaterClosure>> listClosuresForClub(String clubId) async {
    final client = supabaseOrNull();
    if (client == null) return const [];
    try {
      final data = await client
          .from('water_closures')
          .select()
          .eq('club_id', clubId);
      if (data is! List) return const [];
      return [
        for (final e in data)
          if (e is Map)
            WaterClosure(
              id: e['id'] as String,
              waterId: e['water_id'] as String,
              from: DateTime.parse(e['starts_at'] as String),
              to: DateTime.parse(e['ends_at'] as String),
              reason: WaterVetoReasonX.tryParse(e['reason'] as String?) ??
                  WaterVetoReason.autre,
              note: e['note'] as String?,
            ),
      ];
    } catch (e) {
      debugPrint('water_closures list FAIL: $e');
      return const [];
    }
  }
}

class MemoryWaterRemote implements WaterRemote {
  final closures = <WaterClosure>[];

  @override
  Future<void> upsertClosure(
    WaterClosure c, {
    String? clubId,
    String? createdBy,
  }) async {
    closures.removeWhere((e) => e.id == c.id);
    closures.add(c);
  }

  @override
  Future<void> deleteClosure(String id) async {
    closures.removeWhere((e) => e.id == id);
  }

  @override
  Future<List<WaterClosure>> listClosuresForClub(String clubId) async =>
      List.of(closures);
}
