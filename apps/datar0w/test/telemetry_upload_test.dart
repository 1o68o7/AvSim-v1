import 'dart:io';
import 'dart:math';

import 'package:datar0w/session/session_pack.dart';
import 'package:datar0w/session/session_sync.dart';
import 'package:datar0w/sync/outbox_db.dart';
import 'package:datar0w/sync/telemetry_upload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late MemoryBlobSink sink;
  late SessionSync sync;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('datar0w_up_');
    await File('${dir.path}/meta.json')
        .writeAsString('{"id":"s1","clubId":"club-a"}');
    await File('${dir.path}/samples.jsonl').writeAsString('{"t":1}\n');
    sink = MemoryBlobSink();
    sync = SessionSync(
      db: OutboxDb.memory(),
      gateway: TelemetryUploadEngine(sink: sink),
    );
  });

  tearDown(() async {
    sync.db.dispose();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('upload OK → row synced', () async {
    await sync.enqueueAfterStop('s1', dir: dir);
    await sync.drain();
    final row = sync.db.all().single;
    expect(row.acked, isTrue);
    expect(sink.metas[row.syncId]?['payload_sha256'], packSessionDir(dir).sha256hex);
    expect(sink.blobs.values, isNotEmpty);
  });

  test('upload KO → retry', () async {
    sink.fail = true;
    await sync.enqueueAfterStop('s1', dir: dir);
    await sync.drain();
    expect(sync.db.all().single.acked, isFalse);
    expect(sync.db.all().single.attempts, 1);
    sink.fail = false;
    final t = DateTime.now().toUtc().add(const Duration(minutes: 2));
    sync.now = () => t;
    await sync.drain();
    expect(sync.db.all().single.acked, isTrue);
  });

  test('resumable offset jsonl > seuil', () async {
    final pack = packSessionDir(dir);
    final half = max(1, pack.bytes.length ~/ 2);
    final engine = TelemetryUploadEngine(
      sink: sink,
      resumableAfter: 1,
      chunkSize: half,
    );
    final row = OutboxRow(
      syncId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      path: dir.path,
    );
    final r1 = await engine.uploadAndUpsert(
      row: row,
      pack: pack,
      meta: {'clubId': 'c1', 'id': 's1'},
    );
    expect(r1.ok, isTrue);
    expect(r1.acked, isFalse);
    var cur = row.copyWith(uploadOffset: r1.nextOffset);
    UploadResult last = r1;
    while (!last.acked) {
      last = await engine.uploadAndUpsert(
        row: cur,
        pack: pack,
        meta: {'clubId': 'c1', 'id': 's1'},
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
}
