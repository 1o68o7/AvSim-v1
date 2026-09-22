import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../session/session_pack.dart';
import '../session/session_sync.dart';
import 'config.dart';
import 'outbox_db.dart';
import 'supabase_boot.dart';

const kResumableMinBytes = 10 * 1024 * 1024;

/// Chemin Storage privé : `{club_id}/{sync_id}.zip`.
String sessionStoragePath({
  required String clubId,
  required String syncId,
}) =>
    '$clubId/$syncId.zip';

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
  bool fail = false;

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
    if (fail) throw StateError('upsert KO');
    final id = row['sync_id'] as String;
    metas[id] = Map<String, dynamic>.from(row);
  }
}

class TelemetryUploadEngine implements TelemetryGateway {
  TelemetryUploadEngine({
    required this.sink,
    this.resumableAfter = kResumableMinBytes,
    this.chunkSize = 5 * 1024 * 1024,
  });

  final BlobSink sink;
  final int resumableAfter;
  final int chunkSize;

  @override
  Future<UploadResult> uploadAndUpsert({
    required OutboxRow row,
    required SessionPack pack,
    required Map<String, dynamic> meta,
  }) async {
    try {
      final clubId = (meta['clubId'] as String?) ??
          (meta['club_id'] as String?) ??
          'unknown';
      final path = sessionStoragePath(clubId: clubId, syncId: row.syncId);
      final bytes = pack.bytes;
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
      final now = DateTime.now().toUtc().toIso8601String();
      await sink.upsertMeta({
        'sync_id': row.syncId,
        'club_id': clubId,
        'local_session_id': meta['id'] ?? row.path,
        'code': meta['code'],
        'class': meta['class'] ?? meta['classe'],
        'payload_sha256': pack.sha256hex,
        'byte_size': bytes.length,
        'storage_path': path,
        'synced_at': now,
        'started_at': meta['started_at'],
        'ended_at': meta['ended_at'],
        'owner_user_id': meta['owner_user_id'],
        'rower_id': meta['rowerId'] ?? meta['rower_id'],
      });
      return const UploadResult(ok: true, acked: true);
    } catch (e) {
      return UploadResult(ok: false, error: '$e');
    }
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
    await client.from('session_meta').upsert(row);
  }
}

TelemetryGateway liveTelemetryGateway() {
  if (!SyncConfig.enabled) return const SilentTelemetryGateway();
  return TelemetryUploadEngine(sink: SupabaseBlobSink());
}
