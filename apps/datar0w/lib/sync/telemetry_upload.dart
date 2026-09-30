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

/// Colonnes INSERT minimales (0005) — pas de champs optionnels / inconnus.
const kSessionMetaInsertKeys = <String>{
  'sync_id',
  'club_id',
  'local_session_id',
  'code',
  'owner_user_id',
  'storage_path',
  'payload_sha256',
  'byte_size',
  'synced_at',
};

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

/// Payload INSERT minimal — drop nulls et colonnes hors [kSessionMetaInsertKeys].
Map<String, dynamic> minimalSessionMetaPayload(Map<String, dynamic> raw) {
  final out = <String, dynamic>{};
  for (final k in kSessionMetaInsertKeys) {
    final v = raw[k];
    if (v != null) out[k] = v;
  }
  return out;
}

/// Extrait un code PostgREST court pour le bandeau (`42501`, `23505`, `409`).
String? postgrestErrorCode(Object e) {
  if (e is PostgrestException) {
    final c = e.code;
    if (c != null && c.isNotEmpty) return c;
  }
  final m = RegExp(r'\b(42501|23505|409|PGRST\d+)\b').firstMatch('$e');
  return m?.group(1);
}

/// Schéma `0005_session_meta.sql` :
/// - PK : `sync_id`
/// - UNIQUE : `(club_id, local_session_id)`
/// - `code` text (peut différer de local_session_id en prod / rattrapage)

abstract class BlobSink {
  Future<void> put({
    required String storagePath,
    required Uint8List bytes,
    required int offset,
  });

  /// Upsert méta. Match club+local **ou** club+code.
  Future<void> upsertMeta(Map<String, dynamic> row);

  /// Zip déjà présent (Storage) pour ce path.
  Future<bool> objectExists(String storagePath);
}

class MemoryBlobSink implements BlobSink {
  final Map<String, Uint8List> blobs = {};
  final Map<String, Map<String, dynamic>> metas = {};
  /// Index `club_id|local_session_id`.
  final Map<String, Map<String, dynamic>> metasByLocal = {};
  /// Index `club_id|code` (rattrapage : local_session_id ≠ code).
  final Map<String, Map<String, dynamic>> metasByCode = {};
  bool fail = false;
  bool failMetaOnly = false;

  /// Simule échec méta pour un local_session_id (ex. QEPSSL) avec code PG.
  String? failMetaForLocal;
  String failMetaPgCode = '42501';

  bool simulatePkConflict = false;

  void seedMeta(Map<String, dynamic> row) {
    final copy = Map<String, dynamic>.from(row);
    final syncId = copy['sync_id'] as String;
    final club = copy['club_id'] as String?;
    final local = copy['local_session_id'] as String?;
    final code = copy['code'] as String?;
    metas[syncId] = copy;
    if (club != null && local != null) {
      metasByLocal['$club|$local'] = copy;
    }
    if (club != null && code != null && code.isNotEmpty) {
      metasByCode['$club|$code'] = copy;
    }
  }

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
  Future<bool> objectExists(String storagePath) async =>
      blobs.containsKey(storagePath) && blobs[storagePath]!.isNotEmpty;

  Map<String, dynamic>? _findExisting({
    required String? club,
    required String? local,
    required String? code,
    required String syncId,
  }) {
    if (club != null && local != null) {
      final byLocal = metasByLocal['$club|$local'];
      if (byLocal != null) return byLocal;
    }
    if (club != null && code != null && code.isNotEmpty) {
      final byCode = metasByCode['$club|$code'];
      if (byCode != null) return byCode;
    }
    return metas[syncId];
  }

  void _index(Map<String, dynamic> copy) {
    final syncId = copy['sync_id'] as String;
    final club = copy['club_id'] as String?;
    final local = copy['local_session_id'] as String?;
    final code = copy['code'] as String?;
    metas[syncId] = copy;
    if (club != null && local != null) {
      metasByLocal['$club|$local'] = copy;
    }
    if (club != null && code != null && code.isNotEmpty) {
      metasByCode['$club|$code'] = copy;
    }
  }

  @override
  Future<void> upsertMeta(Map<String, dynamic> row) async {
    if (fail || failMetaOnly) throw StateError('upsert KO');
    final syncId = row['sync_id'] as String;
    final club = row['club_id'] as String?;
    final local = row['local_session_id'] as String?;
    final code = (row['code'] as String?) ?? local;

    if (failMetaForLocal != null &&
        (local == failMetaForLocal || code == failMetaForLocal)) {
      throw PostgrestException(
        message: 'RLS/policy denied for $failMetaForLocal',
        code: failMetaPgCode,
        details: null,
        hint: null,
      );
    }

    final existing = _findExisting(
      club: club,
      local: local,
      code: code,
      syncId: syncId,
    );
    if (existing != null) {
      final keepSync = existing['sync_id'] as String;
      final copy = Map<String, dynamic>.from(row);
      copy['sync_id'] = keepSync;
      // Conserve local_session_id cloud (peut être un uuid de rattrapage).
      if (existing['local_session_id'] != null) {
        copy['local_session_id'] = existing['local_session_id'];
      }
      if (keepSync != syncId) metas.remove(syncId);
      _index(copy);
      return;
    }

    if (simulatePkConflict && metas.containsKey(syncId)) {
      throw PostgrestException(
        message: 'duplicate key value violates unique constraint '
            '"session_meta_pkey"',
        code: '23505',
        details: 'Key (sync_id)=($syncId) already exists.',
        hint: null,
      );
    }

    final copy = minimalSessionMetaPayload(row);
    _index(copy);
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

  final String? Function()? resolveOwnerUserId;
  final String? Function()? resolveClubId;

  String? _ownerUserId() =>
      resolveOwnerUserId?.call() ?? defaultOwnerUserId();

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
    final code = (meta['code'] as String?)?.trim().isNotEmpty == true
        ? (meta['code'] as String).trim()
        : localId;
    final path = sessionStoragePath(clubId: clubId, syncId: row.syncId);
    final bytes = pack.bytes;
    var zipOk = false;
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
      zipOk = true;
    } catch (e) {
      debugPrint('session-telemetry put FAIL: $e');
      return UploadResult(ok: false, acked: false, error: 'storage');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final payload = minimalSessionMetaPayload({
      'sync_id': row.syncId,
      'club_id': clubId,
      'local_session_id': localId,
      'code': code,
      'owner_user_id': owner,
      'storage_path': path,
      'payload_sha256': pack.sha256hex,
      'byte_size': bytes.length,
      'synced_at': now,
    });
    try {
      await sink.upsertMeta(payload);
    } on PostgrestException catch (e) {
      final pg = e.code ?? postgrestErrorCode(e) ?? 'session_meta';
      debugPrint(
        'session_meta upsert PostgrestException '
        'code=$pg message=${e.message}',
      );
      // 23505 = déjà la même séance ; zip poussé juste avant → ACK.
      if (pg == '23505' && zipOk) {
        debugPrint('session_meta 23505 + zip → ACK code=$code');
        return const UploadResult(ok: true, acked: true);
      }
      // Bandeau : sync: 42501 / 409 — pas le pavé PostgREST.
      return UploadResult(ok: false, acked: false, error: pg);
    } catch (e) {
      debugPrint('session_meta upsert FAIL: $e');
      final pg = postgrestErrorCode(e);
      if (pg == '23505' && zipOk) {
        return const UploadResult(ok: true, acked: true);
      }
      return UploadResult(
        ok: false,
        acked: false,
        error: pg ?? 'session_meta',
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
    await client.storage.from('session-telemetry').uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
  }

  @override
  Future<bool> objectExists(String storagePath) async {
    final client = supabaseOrNull();
    if (client == null) return false;
    try {
      final slash = storagePath.lastIndexOf('/');
      final folder = slash >= 0 ? storagePath.substring(0, slash) : '';
      final name = slash >= 0 ? storagePath.substring(slash + 1) : storagePath;
      final listed =
          await client.storage.from('session-telemetry').list(path: folder);
      for (final f in listed) {
        if (f.name == name) return true;
      }
      return false;
    } catch (e) {
      debugPrint('session-telemetry exists? $storagePath → $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _findRow({
    required SupabaseClient client,
    required String clubId,
    required String localId,
    required String code,
    required String syncId,
  }) async {
    // 1) club + local_session_id
    final byLocal = await client
        .from('session_meta')
        .select('sync_id, club_id, local_session_id, code, storage_path')
        .eq('club_id', clubId)
        .eq('local_session_id', localId)
        .maybeSingle();
    if (byLocal != null) return Map<String, dynamic>.from(byLocal);

    // 2) club + code (rattrapage : local_session_id = uuid ≠ QEPSSL)
    if (code.isNotEmpty) {
      final byCode = await client
          .from('session_meta')
          .select('sync_id, club_id, local_session_id, code, storage_path')
          .eq('club_id', clubId)
          .eq('code', code)
          .limit(1)
          .maybeSingle();
      if (byCode != null) return Map<String, dynamic>.from(byCode);
    }

    // 3) sync_id
    final bySync = await client
        .from('session_meta')
        .select('sync_id, club_id, local_session_id, code, storage_path')
        .eq('sync_id', syncId)
        .maybeSingle();
    if (bySync != null) return Map<String, dynamic>.from(bySync);
    return null;
  }

  @override
  Future<void> upsertMeta(Map<String, dynamic> row) async {
    final client = supabaseOrNull();
    if (client == null) throw StateError('supabase off');

    final clubId = row['club_id'] as String;
    final localId = row['local_session_id'] as String;
    final syncId = row['sync_id'] as String;
    final code = (row['code'] as String?) ?? localId;
    final minimal = minimalSessionMetaPayload(row);
    final updateFields = Map<String, dynamic>.from(minimal)..remove('sync_id');
    // Ne pas écraser un local_session_id cloud uuid avec le basename.

    try {
      final existing = await _findRow(
        client: client,
        clubId: clubId,
        localId: localId,
        code: code,
        syncId: syncId,
      );
      if (existing != null) {
        final cloudSync = existing['sync_id'] as String;
        final cloudLocal = existing['local_session_id'] as String?;
        final patch = Map<String, dynamic>.from(updateFields);
        if (cloudLocal != null && cloudLocal.isNotEmpty) {
          patch.remove('local_session_id');
        }
        try {
          await client
              .from('session_meta')
              .update(patch)
              .eq('sync_id', cloudSync);
          debugPrint(
            'session_meta UPDATE by match '
            'sync=$cloudSync code=$code local_cloud=$cloudLocal',
          );
        } on PostgrestException catch (e) {
          // UPDATE no-op / RLS : zip peut déjà être là → laisser remonter
          // seulement si ce n’est pas un « déjà synchro ».
          debugPrint(
            'session_meta UPDATE fail code=${e.code} msg=${e.message}',
          );
          if (e.code == '42501' || e.code == '409') {
            // Séance trouvée : considérer méta OK si Storage a l’objet
            // (cloud path ou path courant). Appelant (engine) ACK si zip.
            final cloudPath = existing['storage_path'] as String?;
            final zipThere = (cloudPath != null &&
                    await objectExists(cloudPath)) ||
                await objectExists(minimal['storage_path'] as String);
            if (zipThere) {
              debugPrint(
                'session_meta UPDATE ${e.code} + zip → treat OK code=$code',
              );
              return;
            }
          }
          rethrow;
        }
        return;
      }

      // Vrai INSERT (GT9JDK / GCZEKF) — payload minimal.
      await client.from('session_meta').upsert(
            minimal,
            onConflict: 'club_id,local_session_id',
            ignoreDuplicates: false,
          );
      debugPrint('session_meta INSERT code=$code sync=$syncId');
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
          code: code,
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

  Future<void> _recover23505({
    required SupabaseClient client,
    required String clubId,
    required String localId,
    required String code,
    required String syncId,
    required Map<String, dynamic> updateFields,
  }) async {
    final existing = await _findRow(
      client: client,
      clubId: clubId,
      localId: localId,
      code: code,
      syncId: syncId,
    );
    if (existing != null) {
      final cloudSync = existing['sync_id'] as String;
      final patch = Map<String, dynamic>.from(updateFields)
        ..remove('local_session_id');
      try {
        await client
            .from('session_meta')
            .update(patch)
            .eq('sync_id', cloudSync);
      } catch (e) {
        debugPrint('session_meta 23505 UPDATE soft-fail: $e');
      }
      debugPrint(
        'session_meta 23505 → déjà synchro code=$code '
        'cloud_sync=$cloudSync',
      );
      return;
    }

    throw PostgrestException(
      message: '23505 sans row club+local/code ni sync_id',
      code: '23505',
      details: 'code=$code local=$localId sync=$syncId',
      hint: null,
    );
  }
}

TelemetryGateway liveTelemetryGateway() {
  if (!SyncConfig.enabled) return const SilentTelemetryGateway();
  return TelemetryUploadEngine(sink: SupabaseBlobSink());
}
