import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../identity/store.dart';
import '../ops/cloud_sync.dart';

/// Sync identité club + derniers imports. Local d’abord.
class ClubImportSync {
  ClubImportSync({required this.identity, http.Client? client})
      : _client = client ?? http.Client();

  final IdentityStore identity;
  final http.Client _client;

  Future<void> snapshotOutbox() async {
    final dir = await identity.root();
    final clubs = await identity.listClubs();
    final trophies = await identity.listTrophies();
    final prefs = await identity.loadState();
    final rows = <Map<String, dynamic>>[
      {
        'table': 'club_identity',
        'rows': [
          for (final c in clubs)
            {
              'club_id': c.id,
              'full_name': c.fullName,
              'slogan': c.slogan,
              'founded_year': c.foundedYear,
              'primary_color': c.primaryColor,
              'secondary_color': c.secondaryColor,
              'crest_path': c.crestPath,
            },
        ],
      },
      {
        'table': 'trophies',
        'rows': [
          for (final t in trophies)
            {
              'id': t.id,
              'club_id': t.clubId,
              'name': t.name,
              'date': t.date.toUtc().toIso8601String().split('T').first,
              'result': t.result,
            },
        ],
      },
      if (prefs.lastImportId != null)
        {
          'table': 'boat_imports',
          'rows': [
            {
              'id': prefs.lastImportId,
              'club_id': prefs.activeClubId,
            },
          ],
        },
    ];
    await File(p.join(dir.path, 'import_outbox.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(rows),
    );
  }

  Future<int> flush() async {
    await snapshotOutbox();
    if (!OpsSyncConfig.enabled) return 0;
    final dir = await identity.root();
    final f = File(p.join(dir.path, 'import_outbox.json'));
    if (!f.existsSync()) return 0;
    final batches = jsonDecode(await f.readAsString()) as List;
    var n = 0;
    for (final raw in batches.whereType<Map>()) {
      final table = raw['table'] as String?;
      final rows = (raw['rows'] as List?) ?? const [];
      if (table == null || rows.isEmpty) continue;
      if (table == 'club_identity') {
        for (final r in rows.whereType<Map>()) {
          await _uploadCrest(Map<String, dynamic>.from(r));
        }
      }
      final uri = Uri.parse(
        '${OpsSyncConfig.url}/rest/v1/$table?on_conflict=${table == 'club_identity' ? 'club_id' : 'id'}',
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
      if (res.statusCode >= 200 && res.statusCode < 300) n += rows.length;
    }
    return n;
  }

  Future<void> _uploadCrest(Map<String, dynamic> row) async {
    final path = row['crest_path'] as String?;
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!file.existsSync()) return;
    final dest = 'crests/${row['club_id']}${p.extension(path)}';
    await _client.post(
      Uri.parse('${OpsSyncConfig.url}/storage/v1/object/club-crests/$dest'),
      headers: {
        'apikey': OpsSyncConfig.anonKey,
        'Authorization': 'Bearer ${OpsSyncConfig.anonKey}',
        'Content-Type': 'image/jpeg',
        'x-upsert': 'true',
      },
      body: await file.readAsBytes(),
    );
    row['crest_storage_path'] = dest;
  }
}
