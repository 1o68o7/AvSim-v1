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
}
