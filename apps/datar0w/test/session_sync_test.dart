import 'dart:io';

import 'package:datar0w/session/session_pack.dart';
import 'package:datar0w/session/session_sync.dart';
import 'package:datar0w/sync/outbox_db.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gw implements TelemetryGateway {
  _Gw({this.ack = false});
  bool ack;
  int calls = 0;

  @override
  Future<UploadResult> uploadAndUpsert({
    required OutboxRow row,
    required SessionPack pack,
    required Map<String, dynamic> meta,
  }) async {
    calls++;
    if (!ack) {
      return const UploadResult(ok: false, error: 'no ack');
    }
    return const UploadResult(ok: true, acked: true);
  }
}

void main() {
  late Directory dir;
  late SessionSync sync;
  late _Gw gw;
  late DateTime t;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('datar0w_outbox_');
    await File('${dir.path}/meta.json').writeAsString('{"id":"s1"}');
    await File('${dir.path}/samples.jsonl').writeAsString('{"t":1}\n');
    gw = _Gw();
    t = DateTime.utc(2026, 9, 22, 12);
    sync = SessionSync(
      db: OutboxDb.memory(),
      gateway: gw,
      now: () => t,
    );
  });

  tearDown(() async {
    sync.db.dispose();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('ACK absent → fichiers intacts', () async {
    await sync.enqueueAfterStop('s1', dir: dir);
    await sync.drain();
    expect(File('${dir.path}/meta.json').existsSync(), isTrue);
    expect(File('${dir.path}/samples.jsonl').existsSync(), isTrue);
    expect(sync.db.all().single.acked, isFalse);
  });

  test('3 échecs → bandeau', () async {
    await sync.enqueueAfterStop('s1', dir: dir);
    await sync.drain();
    t = t.add(const Duration(minutes: 2));
    await sync.drain();
    t = t.add(const Duration(minutes: 6));
    await sync.drain();
    expect(sync.unsyncedBannerCount, 1);
    expect(sync.db.all().single.attempts, 3);
  });

  testWidgets('bandeau 1 séance non synchronisée — renvoyer', (tester) async {
    await sync.enqueueAfterStop('s1', dir: dir);
    await sync.drain();
    t = t.add(const Duration(minutes: 2));
    await sync.drain();
    t = t.add(const Duration(minutes: 6));
    await sync.drain();
    await tester.pumpWidget(
      MaterialApp(
        home: SessionSyncHost(
          sync: sync,
          child: const Scaffold(body: Text('body')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('1 séance non synchronisée — renvoyer'), findsOneWidget);
  });

  test('re-push même sync_id = no-op', () async {
    final a = await sync.enqueueAfterStop('s1', dir: dir);
    final b = await sync.enqueueAfterStop('s1', dir: dir);
    expect(b.syncId, a.syncId);
    expect(sync.db.all(), hasLength(1));
    expect(sync.db.insertIdempotent(a).syncId, a.syncId);
    expect(gw.calls, 0);
  });
}
