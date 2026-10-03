import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/cadence_backfill.dart';
import '../session/store.dart';
import '../session/summary.dart';
import 'club_sql.dart';
import 'supabase_boot.dart';

/// Pack local (samples + imu) pour [code] → backfill puis libellé liste/home.
/// Sans IMU local → null (UI : « cadence non mesurée »). Jamais la méta cloud.
Future<String?> resolveLocalCadenceLabel(
  String code, {
  Directory? root,
}) async {
  final id = await SessionStore.findIdByCode(code, root: root);
  if (id == null) return null;
  final base = root ?? await SessionStore.sessionsRootIfPresent();
  if (base == null) return null;
  final dir = Directory('${base.path}/$id');
  final samplesFile = File('${dir.path}/samples.jsonl');
  final imuFile = File('${dir.path}/imu.jsonl');
  if (!samplesFile.existsSync() || !imuFile.existsSync()) return null;
  await CadenceBackfill.maybeBackfill(id, root: base);
  final samples = await SessionStore.loadSamples(id, root: base);
  if (samples.isEmpty) return null;
  return SessionSummary.fromSamples(samples).cadenceLabel;
}

/// Affichage fiche club : local (même contrat liste) ou « non mesurée ».
String formatClubCadenceDisplay(String? localLabel) {
  if (localLabel == null) return 'cadence non mesurée';
  if (localLabel == '—') return '—';
  return '$localLabel spm';
}

/// Ligne `session_meta` cloud (ST-05 / ST-06).
class ClubSessionMeta {
  const ClubSessionMeta({
    required this.syncId,
    required this.code,
    required this.clubId,
    this.ownerUserId,
    this.storagePath,
    this.byteSize,
    this.syncedAt,
    this.createdAt,
    this.localSessionId,
    this.boatClass,
    this.startedAt,
    this.endedAt,
    this.distM,
    this.durationS,
    this.cadenceSpm,
    this.giteRmsDeg,
  });

  final String syncId;
  final String code;
  final String clubId;
  final String? ownerUserId;
  final String? storagePath;
  final int? byteSize;
  final DateTime? syncedAt;
  final DateTime? createdAt;
  final String? localSessionId;
  final String? boatClass;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final double? distM;
  final double? durationS;
  final double? cadenceSpm;
  final double? giteRmsDeg;

  String get sizeLabel {
    final b = byteSize;
    if (b == null) return '—';
    if (b < 1024) return '$b o';
    final ko = (b / 1024).round();
    return '$ko Ko';
  }

  DateTime? get displayDate => syncedAt ?? createdAt ?? startedAt;

  factory ClubSessionMeta.fromSql(Map<String, dynamic> row) {
    DateTime? parseTs(Object? v) {
      if (v == null) return null;
      return DateTime.tryParse('$v')?.toUtc();
    }

    double? numOrNull(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse('$v');
    }

    int? intOrNull(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v');
    }

    return ClubSessionMeta(
      syncId: '${row['sync_id'] ?? ''}',
      code: '${row['code'] ?? row['local_session_id'] ?? ''}',
      clubId: '${row['club_id'] ?? ''}',
      ownerUserId: row['owner_user_id'] as String?,
      storagePath: row['storage_path'] as String?,
      byteSize: intOrNull(row['byte_size']),
      syncedAt: parseTs(row['synced_at']),
      createdAt: parseTs(row['created_at']),
      localSessionId: row['local_session_id'] as String?,
      boatClass: row['class'] as String?,
      startedAt: parseTs(row['started_at']),
      endedAt: parseTs(row['ended_at']),
      distM: numOrNull(row['dist_m']),
      durationS: numOrNull(row['duration_s']),
      cadenceSpm: numOrNull(row['cadence_spm'] ?? row['spm_moy']),
      giteRmsDeg: numOrNull(row['gite_rms_deg']),
    );
  }
}

abstract class ClubSessionRemote {
  Future<List<ClubSessionMeta>> listForClub(String clubId);
  Future<ClubSessionMeta?> byCode(String clubId, String code);
}

final clubSessionRemoteProvider =
    Provider<ClubSessionRemote>((ref) => LiveClubSessionRemote());

class MemoryClubSessionRemote implements ClubSessionRemote {
  MemoryClubSessionRemote([this.rows = const []]);

  List<ClubSessionMeta> rows;

  @override
  Future<List<ClubSessionMeta>> listForClub(String clubId) async =>
      [for (final r in rows) if (r.clubId == clubId) r];

  @override
  Future<ClubSessionMeta?> byCode(String clubId, String code) async {
    final needle = code.trim().toUpperCase();
    for (final r in rows) {
      if (r.clubId == clubId && r.code.toUpperCase() == needle) return r;
    }
    return null;
  }
}

class LiveClubSessionRemote implements ClubSessionRemote {
  static const _select =
      'sync_id, club_id, local_session_id, code, owner_user_id, '
      'storage_path, byte_size, synced_at, created_at, class, '
      'started_at, ended_at, dist_m, duration_s';

  @override
  Future<List<ClubSessionMeta>> listForClub(String clubId) async {
    final client = supabaseOrNull();
    if (client == null || clubId.isEmpty) return const [];
    try {
      final data = await client
          .from('session_meta')
          .select(_select)
          .eq('club_id', clubId)
          .order('created_at', ascending: false)
          .limit(100);
      return [
        for (final r in asRowList(data)) ClubSessionMeta.fromSql(r),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<ClubSessionMeta?> byCode(String clubId, String code) async {
    final client = supabaseOrNull();
    if (client == null || clubId.isEmpty) return null;
    final needle = code.trim().toUpperCase();
    if (needle.isEmpty) return null;
    try {
      final data = await client
          .from('session_meta')
          .select(_select)
          .eq('club_id', clubId)
          .eq('code', needle)
          .limit(1);
      final list = asRowList(data);
      if (list.isEmpty) return null;
      return ClubSessionMeta.fromSql(list.first);
    } catch (_) {
      return null;
    }
  }
}
