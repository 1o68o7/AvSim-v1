import 'package:flutter/foundation.dart';

import '../funnel/models.dart';
import '../identity/id.dart';
import 'supabase_boot.dart';

/// Upsert KPI erg dans `session_meta` (colonnes 0008). Pas de PDF, pas de zip.
Future<bool> upsertErgSessionMeta({
  required ErgSessionLog log,
  required String ownerUserId,
  required String clubId,
  String origin = 'indoor',
}) async {
  final client = supabaseOrNull();
  if (client == null) return false;
  final syncId = newIdentityId();
  final localId = 'erg-${log.at.toUtc().millisecondsSinceEpoch}';
  final row = <String, dynamic>{
    'sync_id': syncId,
    'club_id': clubId,
    'local_session_id': localId,
    'code': localId,
    'owner_user_id': ownerUserId,
    // Jamais un path licence PDF.
    'storage_path': 'erg/$ownerUserId/$localId.json',
    'payload_sha256': 'erg-local',
    'byte_size': 0,
    'synced_at': DateTime.now().toUtc().toIso8601String(),
    'dist_m': log.distM,
    'duration_s': log.durationS,
    'split_500_s': log.split500S,
    if (log.cadence != null) 'cadence': log.cadence,
    if (log.watts != null) 'watts': log.watts,
    if (log.dragFactor != null) 'drag_factor': log.dragFactor,
    'origin': origin == 'remplacement' ? 'remplacement' : 'indoor',
  };
  try {
    await client.from('session_meta').upsert(row);
    return true;
  } catch (e) {
    debugPrint('upsertErgSessionMeta FAIL: $e');
    return false;
  }
}
