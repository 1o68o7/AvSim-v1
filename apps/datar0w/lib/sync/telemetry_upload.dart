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
  /// Index `club_id|local_session_id` (onConflict).
  final Map<String, Map<String, dynamic>> metasByLocal = {};
  bool fail = false;
  bool failMetaOnly = false;

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
    } catch (e) {
      // Zip peut déjà être là : retry meta, même sync_id, pas d’ACK.
      debugPrint('session_meta upsert FAIL status/body: $e');
      return UploadResult(
        ok: false,
        acked: false,
        error: 'session_meta: $e',
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
    try {
      await client.from('session_meta').upsert(
            row,
            onConflict: 'club_id,local_session_id',
          );
    } on PostgrestException catch (e) {
      debugPrint(
        'session_meta upsert PostgrestException '
        'code=${e.code} message=${e.message} details=${e.details} '
        'hint=${e.hint}',
      );
      rethrow;
    } catch (e) {
      debugPrint('session_meta upsert FAIL: $e');
      rethrow;
    }
  }
}

TelemetryGateway liveTelemetryGateway() {
  if (!SyncConfig.enabled) return const SilentTelemetryGateway();
  return TelemetryUploadEngine(sink: SupabaseBlobSink());
}
