import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../identity/store.dart';
import 'boat_out.dart';
import 'impact_report.dart';
import 'store.dart';

/// Sync Point C → Supabase. Local d’abord (outbox). Clés via dart-define.
class OpsSyncConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get enabled => url.isNotEmpty && anonKey.isNotEmpty;
}

class OpsCloudSync {
  OpsCloudSync({
    required this.ops,
    required this.identity,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final OpsStore ops;
  final IdentityStore identity;
  final http.Client _client;

  Future<void> snapshotOutbox() async {
    final boats = await identity.listBoats();
    String clubOf(String boatId) {
      for (final b in boats) {
        if (b.id == boatId) return b.clubId;
      }
      return '';
    }

    final outs = await ops.listOuts();
    final sets = await ops.listOarSets();
    final impacts = await ops.listImpacts();
    final queue = await ops.listQueue();
    await ops.writeOutbox([
      {
        'table': 'oar_sets',
        'rows': [
          for (final s in sets)
            {
              'id': s.id,
              'club_id': clubOf(s.boatId),
              'boat_id': s.boatId,
              'items': s.items.map((e) => e.toJson()).toList(),
              'checked_out_at': s.checkedOutAt.toUtc().toIso8601String(),
              'frozen': s.frozen,
            },
        ],
      },
      {
        'table': 'boat_outs',
        'rows': [
          for (final o in outs)
            {
              'id': o.id,
              'club_id': clubOf(o.boatId),
              'boat_id': o.boatId,
              'coach_id': o.coachId,
              'started_at': o.startedAt.toUtc().toIso8601String(),
              'planned_end': o.plannedEnd?.toUtc().toIso8601String(),
              'ended_at': o.endedAt?.toUtc().toIso8601String(),
              'status': o.status.wire,
              'oar_set_id': o.oarSetId,
              'crew_frozen': o.crewFrozen,
              'transferred_from_coach_id': o.transferredFromCoachId,
              'transferred_at': o.transferredAt?.toUtc().toIso8601String(),
              'oars_ok': o.oarsOk,
              'oars_missing_note': o.oarsMissingNote,
            },
        ],
      },
      {
        'table': 'impact_reports',
        'rows': [
          for (final r in impacts)
            {
              'id': r.id,
              'club_id': clubOf(r.boatId),
              'boat_id': r.boatId,
              'photo_path': r.photoPath,
              'note': r.note,
              'reported_by': r.reportedBy,
              'reported_at': r.reportedAt.toUtc().toIso8601String(),
              'status': r.status.wire,
            },
        ],
      },
      {
        'table': 'checkout_queue',
        'rows': [
          for (final q in queue)
            {
              'id': q.id,
              'club_id': clubOf(q.boatId),
              'boat_id': q.boatId,
              'coach_id': q.coachId,
              'requested_at': q.requestedAt.toUtc().toIso8601String(),
              'message': q.message,
            },
        ],
      },
    ]);
  }

  /// Upsert REST. Photos : Storage `impact-photos` si fichier local présent.
  Future<int> flush() async {
    await snapshotOutbox();
    if (!OpsSyncConfig.enabled) return 0;
    final batches = await ops.readOutbox();
    var n = 0;
    for (final b in batches) {
      final table = b['table'] as String?;
      final rows = (b['rows'] as List?) ?? const [];
      if (table == null || rows.isEmpty) continue;
      if (table == 'impact_reports') {
        for (final raw in rows.whereType<Map>()) {
          await _uploadPhoto(Map<String, dynamic>.from(raw));
        }
      }
      final uri = Uri.parse(
        '${OpsSyncConfig.url}/rest/v1/$table?on_conflict=id',
      );
      final res = await _client.post(
        uri,
        headers: {
          'apikey': OpsSyncConfig.anonKey,
          'Authorization': 'Bearer ${OpsSyncConfig.anonKey}',
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates,return=minimal',
        },
        body: jsonEncode(rows),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        n += rows.length;
      }
    }
    return n;
  }

  Future<void> _uploadPhoto(Map<String, dynamic> row) async {
    final path = row['photo_path'] as String?;
    if (path == null || path.isEmpty) return;
    final f = File(path);
    if (!f.existsSync()) return;
    final dest = 'impacts/${row['id']}${p.extension(path)}';
    final uri = Uri.parse(
      '${OpsSyncConfig.url}/storage/v1/object/impact-photos/$dest',
    );
    await _client.post(
      uri,
      headers: {
        'apikey': OpsSyncConfig.anonKey,
        'Authorization': 'Bearer ${OpsSyncConfig.anonKey}',
        'Content-Type': 'image/jpeg',
        'x-upsert': 'true',
      },
      body: await f.readAsBytes(),
    );
    row['photo_storage_path'] = dest;
  }
}
