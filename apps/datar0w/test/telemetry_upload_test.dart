import 'dart:io';
import 'dart:math';

import 'package:datar0w/session/session_pack.dart';
import 'package:datar0w/session/session_sync.dart';
import 'package:datar0w/sync/outbox_db.dart';
import 'package:datar0w/sync/telemetry_upload.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

TelemetryUploadEngine _engine(MemoryBlobSink sink) => TelemetryUploadEngine(
      sink: sink,
      resolveOwnerUserId: () => '143623bb-577b-4efc-ab39-154a6ecd2de8',
      resolveClubId: () => '169c88f1-8627-4e6e-a757-9b225c568771',
    );

void main() {
  late Directory dir;
  late MemoryBlobSink sink;
  late SessionSync sync;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('datar0w_up_');
    // Dossier nommé comme un code séance (pas un path Android).
    final sessionDir = Directory(p.join(dir.path, 'QEPSSL'));
    await sessionDir.create();
    await File(p.join(sessionDir.path, 'meta.json')).writeAsString(
      '{"id":"QEPSSL","code":"QEPSSL","clubId":"stale-from-meta"}',
    );
    await File(p.join(sessionDir.path, 'samples.jsonl'))
        .writeAsString('{"t":1}\n');
    dir = sessionDir;
    sink = MemoryBlobSink();
    sync = SessionSync(
      db: OutboxDb.memory(),
      gateway: _engine(sink),
    );
  });

  tearDown(() async {
    sync.db.dispose();
    final parent = dir.parent;
    if (parent.existsSync()) await parent.delete(recursive: true);
  });

  test('upload OK → row synced', () async {
    await sync.enqueueAfterStop('QEPSSL', dir: dir);
    await sync.drain(enqueueExisting: false);
    final row = sync.db.all().single;
    expect(row.acked, isTrue);
    expect(
      sink.metas[row.syncId]?['payload_sha256'],
      packSessionDir(dir).sha256hex,
    );
    expect(sink.blobs.values, isNotEmpty);
  });

  test('meta sans owner → engine injecte uid', () async {
    await sync.enqueueAfterStop('QEPSSL', dir: dir);
    await sync.drain(enqueueExisting: false);
    final row = sync.db.all().single;
    final meta = sink.metas[row.syncId]!;
    expect(meta['owner_user_id'], '143623bb-577b-4efc-ab39-154a6ecd2de8');
    expect(meta['club_id'], '169c88f1-8627-4e6e-a757-9b225c568771');
    expect(meta['local_session_id'], 'QEPSSL');
    expect(meta['local_session_id'], isNot(contains('/')));
  });

  test('upsert sans uid → pas d’ACK, pas de put', () async {
    final noUid = TelemetryUploadEngine(
      sink: sink,
      resolveOwnerUserId: () => null,
      resolveClubId: () => '169c88f1-8627-4e6e-a757-9b225c568771',
    );
    sync = SessionSync(db: OutboxDb.memory(), gateway: noUid);
    await sync.enqueueAfterStop('QEPSSL', dir: dir);
    await sync.drain(enqueueExisting: false);
    expect(sync.db.all().single.acked, isFalse);
    expect(sync.db.all().single.lastError, 'pas d\'uid');
    expect(sink.blobs, isEmpty);
    expect(sink.metas, isEmpty);
  });

  test('sans club_id → pas d’ACK ni zip orphelin', () async {
    final noClub = TelemetryUploadEngine(
      sink: sink,
      resolveOwnerUserId: () => '143623bb-577b-4efc-ab39-154a6ecd2de8',
      resolveClubId: () => null,
    );
    // meta sans club non-unknown
    await File(p.join(dir.path, 'meta.json'))
        .writeAsString('{"id":"QEPSSL","code":"QEPSSL"}');
    sync = SessionSync(db: OutboxDb.memory(), gateway: noClub);
    await sync.enqueueAfterStop('QEPSSL', dir: dir);
    await sync.drain(enqueueExisting: false);
    expect(sync.db.all().single.acked, isFalse);
    expect(sync.db.all().single.lastError, 'pas de club');
    expect(sink.blobs, isEmpty);
  });

  test('meta upsert KO après put → pas d’ACK, même sync_id au retry', () async {
    sink.failMetaOnly = true;
    await sync.enqueueAfterStop('QEPSSL', dir: dir);
    await sync.drain(enqueueExisting: false);
    final first = sync.db.all().single;
    expect(first.acked, isFalse);
    expect(sink.blobs, isNotEmpty);
    expect(sink.metas, isEmpty);
    sink.failMetaOnly = false;
    final t = DateTime.now().toUtc().add(const Duration(minutes: 2));
    sync.now = () => t;
    await sync.drain(enqueueExisting: false);
    final again = sync.db.all().single;
    expect(again.syncId, first.syncId);
    expect(again.acked, isTrue);
    expect(sink.metas[again.syncId]?['local_session_id'], 'QEPSSL');
  });

  test('upload KO → retry', () async {
    sink.fail = true;
    await sync.enqueueAfterStop('QEPSSL', dir: dir);
    await sync.drain(enqueueExisting: false);
    expect(sync.db.all().single.acked, isFalse);
    expect(sync.db.all().single.attempts, 1);
    sink.fail = false;
    final t = DateTime.now().toUtc().add(const Duration(minutes: 2));
    sync.now = () => t;
    await sync.drain(enqueueExisting: false);
    expect(sync.db.all().single.acked, isTrue);
  });

  test('resumable offset jsonl > seuil', () async {
    final pack = packSessionDir(dir);
    final half = max(1, pack.bytes.length ~/ 2);
    final engine = TelemetryUploadEngine(
      sink: sink,
      resumableAfter: 1,
      chunkSize: half,
      resolveOwnerUserId: () => 'u1',
      resolveClubId: () => 'c1',
    );
    final row = OutboxRow(
      syncId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      path: dir.path,
    );
    final r1 = await engine.uploadAndUpsert(
      row: row,
      pack: pack,
      meta: {'clubId': 'ignored', 'id': 'QEPSSL'},
    );
    expect(r1.ok, isTrue);
    expect(r1.acked, isFalse);
    var cur = row.copyWith(uploadOffset: r1.nextOffset);
    UploadResult last = r1;
    while (!last.acked) {
      last = await engine.uploadAndUpsert(
        row: cur,
        pack: pack,
        meta: {'clubId': 'ignored', 'id': 'QEPSSL'},
      );
      cur = cur.copyWith(uploadOffset: last.nextOffset);
      expect(last.ok, isTrue);
    }
    expect(sink.blobs['c1/${row.syncId}.zip']!.length, pack.bytes.length);
  });

  test('storage path prefix club_id', () {
    expect(
      sessionStoragePath(clubId: 'club-a', syncId: 's'),
      'club-a/s.zip',
    );
  });

  test('localSessionIdFor = basename dossier', () {
    final row = OutboxRow(
      syncId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      path: '/data/user/0/app/files/sessions/GT9JDK',
    );
    expect(localSessionIdFor(row, {'id': 'other'}), 'GT9JDK');
  });

  test('enqueueExistingLocalSessions file les non-ACK', () async {
    final root = dir.parent;
    final other = Directory(p.join(root.path, 'GCZEKF'));
    await other.create();
    await File(p.join(other.path, 'meta.json'))
        .writeAsString('{"id":"GCZEKF","code":"GCZEKF"}');
    await File(p.join(other.path, 'samples.jsonl')).writeAsString('{}\n');

    final n = await sync.enqueueExistingLocalSessions(root: root);
    expect(n, 2);
    expect(sync.db.all(), hasLength(2));
    final codes = sync.db.all().map((r) => p.basename(r.path)).toSet();
    expect(codes, containsAll(['QEPSSL', 'GCZEKF']));
    // 2e appel : déjà en file, encore enqueue (idempotent sync_id)
    final again = await sync.enqueueExistingLocalSessions(root: root);
    expect(again, 2);
    expect(sync.db.all(), hasLength(2));
  });

  test('2e push QEPSSL même sync_id → ACK, une seule ligne', () async {
    final engine = _engine(sink);
    final pack = packSessionDir(dir);
    const club = '169c88f1-8627-4e6e-a757-9b225c568771';
    final row = OutboxRow(
      syncId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      path: dir.path,
    );
    final r1 = await engine.uploadAndUpsert(
      row: row,
      pack: pack,
      meta: const {'code': 'QEPSSL'},
    );
    expect(r1.acked, isTrue);
    expect(sink.metas, hasLength(1));
    expect(sink.metasByLocal['$club|QEPSSL'], isNotNull);

    final r2 = await engine.uploadAndUpsert(
      row: row,
      pack: pack,
      meta: const {'code': 'QEPSSL'},
    );
    expect(r2.acked, isTrue);
    expect(sink.metas, hasLength(1));
    expect(sink.metasByLocal, hasLength(1));
  });

  test('2e push QEPSSL autre sync_id → UPDATE, pas de 2e ligne', () async {
    final engine = _engine(sink);
    final pack = packSessionDir(dir);
    const club = '169c88f1-8627-4e6e-a757-9b225c568771';
    final first = OutboxRow(
      syncId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      path: dir.path,
    );
    final r1 = await engine.uploadAndUpsert(
      row: first,
      pack: pack,
      meta: const {'code': 'QEPSSL'},
    );
    expect(r1.acked, isTrue);

    // Re-enqueue local avec un nouveau sync_id (cas 23505 pkey / unique).
    final second = OutboxRow(
      syncId: 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff',
      path: dir.path,
    );
    final r2 = await engine.uploadAndUpsert(
      row: second,
      pack: pack,
      meta: const {'code': 'QEPSSL'},
    );
    expect(r2.acked, isTrue);
    expect(sink.metasByLocal, hasLength(1));
    expect(sink.metas, hasLength(1));
    expect(
      sink.metasByLocal['$club|QEPSSL']?['sync_id'],
      first.syncId,
    );
    expect(sink.metas.containsKey(second.syncId), isFalse);
  });

  test('GT9JDK / GCZEKF absents → vrai INSERT (nouveaux sync_id)', () async {
    final engine = _engine(sink);
    final pack = packSessionDir(dir);
    const club = '169c88f1-8627-4e6e-a757-9b225c568771';

    final q = OutboxRow(
      syncId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      path: dir.path,
    );
    await engine.uploadAndUpsert(
      row: q,
      pack: pack,
      meta: const {'code': 'QEPSSL'},
    );

    final gtDir = Directory(p.join(dir.parent.path, 'GT9JDK'));
    await gtDir.create();
    await File(p.join(gtDir.path, 'meta.json'))
        .writeAsString('{"code":"GT9JDK"}');
    await File(p.join(gtDir.path, 'samples.jsonl')).writeAsString('{}\n');
    final gt = OutboxRow(
      syncId: '11111111-2222-4333-8444-555555555555',
      path: gtDir.path,
    );
    final rGt = await engine.uploadAndUpsert(
      row: gt,
      pack: packSessionDir(gtDir),
      meta: const {'code': 'GT9JDK'},
    );
    expect(rGt.acked, isTrue);

    final gcDir = Directory(p.join(dir.parent.path, 'GCZEKF'));
    await gcDir.create();
    await File(p.join(gcDir.path, 'meta.json'))
        .writeAsString('{"code":"GCZEKF"}');
    await File(p.join(gcDir.path, 'samples.jsonl')).writeAsString('{}\n');
    final gc = OutboxRow(
      syncId: '66666666-7777-4888-8999-aaaaaaaaaaaa',
      path: gcDir.path,
    );
    final rGc = await engine.uploadAndUpsert(
      row: gc,
      pack: packSessionDir(gcDir),
      meta: const {'code': 'GCZEKF'},
    );
    expect(rGc.acked, isTrue);

    expect(sink.metas, hasLength(3));
    expect(sink.metasByLocal.keys.toSet(), {
      '$club|QEPSSL',
      '$club|GT9JDK',
      '$club|GCZEKF',
    });
  });

  test('cloud code=QEPSSL local_session_id=uuid → UPDATE + ACK', () async {
    const club = '169c88f1-8627-4e6e-a757-9b225c568771';
    const cloudSync = 'cccccccc-dddd-4eee-8fff-000000000000';
    const cloudLocal = '11111111-2222-4333-8444-999999999999';
    sink.seedMeta({
      'sync_id': cloudSync,
      'club_id': club,
      'local_session_id': cloudLocal,
      'code': 'QEPSSL',
      'owner_user_id': '143623bb-577b-4efc-ab39-154a6ecd2de8',
      'storage_path': '$club/$cloudSync.zip',
      'payload_sha256': 'old',
      'byte_size': 1,
      'synced_at': '2026-09-30T11:49:00Z',
    });

    final engine = _engine(sink);
    final row = OutboxRow(
      syncId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      path: dir.path,
    );
    final r = await engine.uploadAndUpsert(
      row: row,
      pack: packSessionDir(dir),
      meta: const {'code': 'QEPSSL'},
    );
    expect(r.acked, isTrue);
    expect(sink.metas, hasLength(1));
    expect(sink.metas[cloudSync]?['local_session_id'], cloudLocal);
    expect(sink.metasByCode['$club|QEPSSL']?['sync_id'], cloudSync);
    expect(sink.metas.containsKey(row.syncId), isFalse);
  });

  test('42501 → pas de throw, error code dans UploadResult', () async {
    sink.failMetaForLocal = 'QEPSSL';
    sink.failMetaPgCode = '42501';
    final engine = _engine(sink);
    final r = await engine.uploadAndUpsert(
      row: OutboxRow(
        syncId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        path: dir.path,
      ),
      pack: packSessionDir(dir),
      meta: const {'code': 'QEPSSL'},
    );
    expect(r.acked, isFalse);
    expect(r.error, '42501');
  });

  test('23505 + zip → ACK sans throw', () async {
    sink.failMetaForLocal = 'QEPSSL';
    sink.failMetaPgCode = '23505';
    final engine = _engine(sink);
    final r = await engine.uploadAndUpsert(
      row: OutboxRow(
        syncId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        path: dir.path,
      ),
      pack: packSessionDir(dir),
      meta: const {'code': 'QEPSSL'},
    );
    expect(r.acked, isTrue);
    expect(sink.blobs, isNotEmpty);
  });

  test('minimalSessionMetaPayload drop class / nulls', () {
    final m = minimalSessionMetaPayload({
      'sync_id': 's',
      'club_id': 'c',
      'local_session_id': 'QEPSSL',
      'code': 'QEPSSL',
      'owner_user_id': 'u',
      'storage_path': 'c/s.zip',
      'payload_sha256': 'h',
      'byte_size': 1,
      'synced_at': 't',
      'class': '8+',
      'rower_id': null,
      'started_at': 'x',
    });
    expect(m.containsKey('class'), isFalse);
    expect(m.containsKey('rower_id'), isFalse);
    expect(m.containsKey('started_at'), isFalse);
    expect(m['code'], 'QEPSSL');
  });
}
