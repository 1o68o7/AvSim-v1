import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../session/session_pack.dart';
import '../session/session_sync.dart';
import 'config.dart';
import 'outbox_db.dart';
import 'supabase_boot.dart';
import 'sync_identity.dart';

const kResumableMinBytes = 10 * 1024 * 1024;

/// Chemin Storage privé : `{club_id}/{sync_id}.zip`.
String sessionStoragePath({
  required String clubId,
  required String syncId,
}) =>
    '$clubId/$syncId.zip';

/// Code séance = basename du dossier `sessions/{CODE}`, jamais le path Android.
String localSessionIdFor(OutboxRow row, Map<String, dynamic> meta) {
  final fromPath = p.basename(row.path);
  if (fromPath.isNotEmpty &&
      fromPath != '.' &&
      fromPath != '..' &&
      !fromPath.contains(r'\') &&
      fromPath != 'sessions') {
    return fromPath;
  }
  final code = meta['code'] as String?;
  if (code != null && code.trim().isNotEmpty) return code.trim();
  final id = meta['id'] as String?;
  if (id != null && id.trim().isNotEmpty && !id.contains('/')) {
    return id.trim();
  }
  return fromPath;
}

/// Schéma `0005_session_meta.sql` :
/// - PK : `sync_id`
/// - UNIQUE : `(club_id, local_session_id)`
/// Upsert PostgREST sur la unique seule ne couvre pas un 23505 PK
/// (re-push même sync_id). Voir [SupabaseBlobSink.upsertMeta].

abstract class BlobSink {
  Future<void> put({
    required String storagePath,
    required Uint8List bytes,
    required int offset,
  });
  Future<void> upsertMeta(Map<String, dynamic> row);
}

class MemoryBlobSink implements BlobSink {
  final Map<String, Uint8List> blobs = {};
  final Map<String, Map<String, dynamic>> metas = {};
  /// Index `club_id|local_session_id` (unique).
  final Map<String, Map<String, dynamic>> metasByLocal = {};
  bool fail = false;
  bool failMetaOnly = false;

  /// Simule 23505 PK si insert aveugle avec sync_id déjà pris par *autre* local.
  bool simulatePkConflict = false;

  @override
  Future<void> put({
    required String storagePath,
    required Uint8List bytes,
    required int offset,
  }) async {
    if (fail) throw StateError('upload KO');
    final prev = blobs[storagePath] ?? Uint8List(0);
    final grow = max(prev.length, offset + bytes.length);
    final out = Uint8List(grow);
    out.setRange(0, prev.length, prev);
    out.setRange(offset, offset + bytes.length, bytes);
    blobs[storagePath] = out;
  }

  @override
  Future<void> upsertMeta(Map<String, dynamic> row) async {
    if (fail || failMetaOnly) throw StateError('upsert KO');
    final syncId = row['sync_id'] as String;
    final club = row['club_id'] as String?;
    final local = row['local_session_id'] as String?;
    final copy = Map<String, dynamic>.from(row);

    // 1) Déjà une row club+code → UPDATE (garde le sync_id cloud).
    if (club != null && local != null) {
      final key = '$club|$local';
      final existing = metasByLocal[key];
      if (existing != null) {
        final keepSync = existing['sync_id'] as String;
        copy['sync_id'] = keepSync;
        metas[keepSync] = copy;
        metasByLocal[key] = copy;
        if (keepSync != syncId) metas.remove(syncId);
        return;
      }
    }

    // 2) Même sync_id déjà en base → UPDATE.
    final bySync = metas[syncId];
    if (bySync != null) {
      metas[syncId] = copy;
      if (club != null && local != null) {
        metasByLocal['$club|$local'] = copy;
      }
      return;
    }

    // 3) INSERT (GT9JDK / GCZEKF).
    if (simulatePkConflict && metas.containsKey(syncId)) {
      throw PostgrestException(
        message: 'duplicate key value violates unique constraint '
            '"session_meta_pkey"',
        code: '23505',
        details: 'Key (sync_id)=($syncId) already exists.',
        hint: null,
      );
    }
    metas[syncId] = copy;
    if (club != null && local != null) {
      metasByLocal['$club|$local'] = copy;
    }
  }
}

class TelemetryUploadEngine implements TelemetryGateway {
  TelemetryUploadEngine({
    required this.sink,
    this.resumableAfter = kResumableMinBytes,
    this.chunkSize = 5 * 1024 * 1024,
    this.resolveOwnerUserId,
    this.resolveClubId,
  });

  final BlobSink sink;
  final int resumableAfter;
  final int chunkSize;

  /// Injecté en tests. Prod : [defaultOwnerUserId] = auth.uid().
  final String? Function()? resolveOwnerUserId;

  /// Injecté en tests. Prod : prefs.activeClubId (membership via ensure).
  final String? Function()? resolveClubId;

  String? _ownerUserId() =>
      resolveOwnerUserId?.call() ?? defaultOwnerUserId();

  /// Club = prefs / mémoire hydrate — **pas** meta.json (JSONL sans club_id).
  String? _clubId(Map<String, dynamic> meta) {
    final fromResolver = resolveClubId?.call();
    if (fromResolver != null && fromResolver.trim().isNotEmpty) {
      return fromResolver.trim();
    }
    final fromPrefs = defaultActiveClubId();
    if (fromPrefs != null && fromPrefs.trim().isNotEmpty) {
      return fromPrefs.trim();
    }
    return null;
  }

  @override
  Future<UploadResult> uploadAndUpsert({
    required OutboxRow row,
    required SessionPack pack,
    required Map<String, dynamic> meta,
  }) async {
    final owner = _ownerUserId();
    if (owner == null || owner.isEmpty) {
      debugPrint('session_meta skip: pas d’uid — pas d’ACK ni zip');
      return const UploadResult(
        ok: false,
        acked: false,
        error: 'pas d\'uid',
      );
    }
    final clubId = _clubId(meta);
    if (clubId == null || clubId.isEmpty) {
      debugPrint('session_meta skip: pas de club — pas d’upload');
      return const UploadResult(
        ok: false,
        acked: false,
        error: 'pas de club',
      );
    }
    final localId = localSessionIdFor(row, meta);
    final path = sessionStoragePath(clubId: clubId, syncId: row.syncId);
    final bytes = pack.bytes;
    try {
      var offset = row.uploadOffset;
      if (bytes.length > resumableAfter) {
        if (offset > bytes.length) offset = 0;
        final end = min(offset + chunkSize, bytes.length);
        await sink.put(
          storagePath: path,
          bytes: Uint8List.fromList(bytes.sublist(offset, end)),
          offset: offset,
        );
        if (end < bytes.length) {
          return UploadResult(ok: true, acked: false, nextOffset: end);
        }
      } else {
        await sink.put(storagePath: path, bytes: bytes, offset: 0);
      }
    } catch (e) {
      debugPrint('session-telemetry put FAIL: $e');
      return UploadResult(ok: false, acked: false, error: 'storage: $e');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'sync_id': row.syncId,
      'club_id': clubId,
      'local_session_id': localId,
      'code': meta['code'] ?? localId,
      'class': meta['class'] ?? meta['classe'],
      'payload_sha256': pack.sha256hex,
      'byte_size': bytes.length,
      'storage_path': path,
      'synced_at': now,
      'started_at': meta['started_at'],
      'ended_at': meta['ended_at'],
      // Toujours auth.uid() — jamais meta.json / jamais id rameur local.
      'owner_user_id': owner,
      'rower_id': meta['rowerId'] ?? meta['rower_id'],
    };
    try {
      await sink.upsertMeta(payload);
    } on PostgrestException catch (e) {
      // 23505 doit être absorbé dans SupabaseBlobSink (ACK via update).
      debugPrint(
        'session_meta upsert PostgrestException '
        'code=${e.code} message=${e.message}',
      );
      return const UploadResult(
        ok: false,
        acked: false,
        error: 'session_meta',
      );
    } catch (e) {
      debugPrint('session_meta upsert FAIL status/body: $e');
      final msg = '$e';
      return UploadResult(
        ok: false,
        acked: false,
        error: msg.contains('upsert KO') ? 'session_meta: $e' : 'session_meta',
      );
    }
    return const UploadResult(ok: true, acked: true);
  }
}

class SupabaseBlobSink implements BlobSink {
  @override
  Future<void> put({
    required String storagePath,
    required Uint8List bytes,
    required int offset,
  }) async {
    final client = supabaseOrNull();
    if (client == null) throw StateError('supabase off');
    // Reprise offset : TUS si > 10 Mo (chunk déjà tranché par l’engine).
    await client.storage.from('session-telemetry').uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
  }

  @override
  Future<void> upsertMeta(Map<String, dynamic> row) async {
    final client = supabaseOrNull();
    if (client == null) throw StateError('supabase off');

    final clubId = row['club_id'] as String;
    final localId = row['local_session_id'] as String;
    final syncId = row['sync_id'] as String;
    final updateFields = Map<String, dynamic>.from(row)..remove('sync_id');

    try {
      // 1) Row déjà là pour club+code → UPDATE (ne pas renvoyer un sync_id
      //    qui créerait un 2e INSERT / changerait la PK d’une autre ligne).
      final byLocal = await client
          .from('session_meta')
          .select('sync_id, club_id, local_session_id, storage_path')
          .eq('club_id', clubId)
          .eq('local_session_id', localId)
          .maybeSingle();
      if (byLocal != null) {
        await client
            .from('session_meta')
            .update(updateFields)
            .eq('club_id', clubId)
            .eq('local_session_id', localId);
        debugPrint(
          'session_meta UPDATE club+local '
          'kept_sync=${byLocal['sync_id']} local=$localId',
        );
        return;
      }

      // 2) Même sync_id déjà en base (re-push outbox) → UPDATE.
      final bySync = await client
          .from('session_meta')
          .select('sync_id, club_id, local_session_id')
          .eq('sync_id', syncId)
          .maybeSingle();
      if (bySync != null) {
        await client
            .from('session_meta')
            .update(updateFields)
            .eq('sync_id', syncId);
        debugPrint('session_meta UPDATE by sync_id=$syncId');
        return;
      }

      // 3) Vrai INSERT (GT9JDK / GCZEKF) — onConflict unique métier.
      await client.from('session_meta').upsert(
            row,
            onConflict: 'club_id,local_session_id',
            ignoreDuplicates: false,
          );
    } on PostgrestException catch (e) {
      debugPrint(
        'session_meta upsert PostgrestException '
        'code=${e.code} message=${e.message} details=${e.details} '
        'hint=${e.hint}',
      );
      if (e.code == '23505') {
        await _recover23505(
          client: client,
          clubId: clubId,
          localId: localId,
          syncId: syncId,
          updateFields: updateFields,
        );
        return;
      }
      rethrow;
    } catch (e) {
      debugPrint('session_meta upsert FAIL: $e');
      rethrow;
    }
  }

  /// 23505 session_meta_pkey ou unique (club, local) :
  /// si la séance est déjà là → update + OK (ACK) ; sinon update by sync_id.
  Future<void> _recover23505({
    required SupabaseClient client,
    required String clubId,
    required String localId,
    required String syncId,
    required Map<String, dynamic> updateFields,
  }) async {
    final byLocal = await client
        .from('session_meta')
        .select('sync_id, club_id, local_session_id')
        .eq('club_id', clubId)
        .eq('local_session_id', localId)
        .maybeSingle();
    if (byLocal != null) {
      // Déjà la même séance (ex. QEPSSL) — zip déjà poussé.
      await client
          .from('session_meta')
          .update(updateFields)
          .eq('club_id', clubId)
          .eq('local_session_id', localId);
      debugPrint(
        'session_meta 23505 → déjà synchro local=$localId '
        'cloud_sync=${byLocal['sync_id']}',
      );
      return;
    }

    final bySync = await client
        .from('session_meta')
        .select('sync_id, storage_path')
        .eq('sync_id', syncId)
        .maybeSingle();
    if (bySync != null) {
      await client
          .from('session_meta')
          .update({
            'storage_path': updateFields['storage_path'],
            'payload_sha256': updateFields['payload_sha256'],
            'byte_size': updateFields['byte_size'],
            'synced_at': updateFields['synced_at'],
          })
          .eq('sync_id', syncId);
      debugPrint('session_meta 23505 → UPDATE storage_path sync_id=$syncId');
      return;
    }

    throw PostgrestException(
      message: '23505 sans row club+local ni sync_id',
      code: '23505',
      details: 'local=$localId sync=$syncId',
      hint: null,
    );
  }
}

TelemetryGateway liveTelemetryGateway() {
  if (!SyncConfig.enabled) return const SilentTelemetryGateway();
  return TelemetryUploadEngine(sink: SupabaseBlobSink());
}
