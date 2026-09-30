import 'dart:io';

import 'package:datar0w/session/session_pack.dart';
import 'package:datar0w/session/session_sync.dart';
import 'package:datar0w/sync/outbox_db.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gw implements TelemetryGateway {
  _Gw();
  bool ack = false;
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
    await sync.drain(enqueueExisting: false);
    expect(File('${dir.path}/meta.json').existsSync(), isTrue);
    expect(File('${dir.path}/samples.jsonl').existsSync(), isTrue);
    expect(sync.db.all().single.acked, isFalse);
  });

  test('3 échecs → bandeau', () async {
    await sync.enqueueAfterStop('s1', dir: dir);
    await sync.drain(enqueueExisting: false);
    t = t.add(const Duration(minutes: 2));
    await sync.drain(enqueueExisting: false);
    t = t.add(const Duration(minutes: 6));
    await sync.drain(enqueueExisting: false);
    expect(sync.unsyncedBannerCount, 1);
    expect(sync.db.all().single.attempts, 3);
  });

  testWidgets('bandeau ST-09 EN FILE sous AppBar, chip seul', (tester) async {
    await sync.enqueueAfterStop('s1', dir: dir);
    await sync.drain(enqueueExisting: false);
    t = t.add(const Duration(minutes: 2));
    await sync.drain(enqueueExisting: false);
    t = t.add(const Duration(minutes: 6));
    await sync.drain(enqueueExisting: false);
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
    expect(find.text('EN FILE'), findsOneWidget);
    expect(find.text('1 en file'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });

  test('autosyncAfterStop sans uid → enqueue, 0 upload', () async {
    SessionSync.debugReplace(
      SessionSync(
        db: OutboxDb.memory(),
        gateway: gw,
        now: () => t,
        resolveOwnerUserId: () => null,
        resolveClubId: () => null,
      ),
    );
    addTearDown(() => SessionSync.debugReplace(null));
    await SessionSync.autosyncAfterStop('s1', dir: dir);
    final shared = SessionSync.shared();
    expect(shared.db.all(), hasLength(1));
    expect(shared.db.all().single.acked, isFalse);
    expect(gw.calls, 0);
  });

  test('autosyncAfterStop uid+club → drain/upload', () async {
    gw.ack = true;
    SessionSync.debugReplace(
      SessionSync(
        db: OutboxDb.memory(),
        gateway: gw,
        now: () => t,
        resolveOwnerUserId: () => 'uid-1',
        resolveClubId: () => 'club-1',
        ensureClub: () async => 'club-1',
      ),
    );
    addTearDown(() => SessionSync.debugReplace(null));
    await SessionSync.autosyncAfterStop('s1', dir: dir);
    expect(gw.calls, greaterThan(0));
    expect(SessionSync.shared().db.all().single.acked, isTrue);
  });

  test('re-push même sync_id = no-op', () async {
    final a = await sync.enqueueAfterStop('s1', dir: dir);
    final b = await sync.enqueueAfterStop('s1', dir: dir);
    expect(b.syncId, a.syncId);
    expect(sync.db.all(), hasLength(1));
    expect(sync.db.insertIdempotent(a).syncId, a.syncId);
    expect(gw.calls, 0);
  });

  test('retryManual attempts=0 → _push (gateway appelé)', () async {
    sync = SessionSync(
      db: OutboxDb.memory(),
      gateway: gw,
      now: () => t,
      resolveOwnerUserId: () => 'uid-1',
      resolveClubId: () => 'club-1',
    );
    await sync.enqueueAfterStop('s1', dir: dir);
    expect(sync.db.all().single.attempts, 0);
    expect(gw.calls, 0);
    await sync.retryManual();
    expect(gw.calls, 1);
    expect(sync.db.all().single.acked, isFalse);
  });

  test('retryManual sans uid → 0 push, lastError posé', () async {
    sync = SessionSync(
      db: OutboxDb.memory(),
      gateway: gw,
      now: () => t,
      resolveOwnerUserId: () => null,
      resolveClubId: () => 'club-1',
    );
    await sync.enqueueAfterStop('s1', dir: dir);
    await sync.retryManual();
    expect(gw.calls, 0);
    final row = sync.db.all().single;
    expect(row.acked, isFalse);
    expect(row.lastError, 'pas d\'uid');
  });

  test('retryManual uid+club + gateway ok → acked', () async {
    gw.ack = true;
    sync = SessionSync(
      db: OutboxDb.memory(),
      gateway: gw,
      now: () => t,
      resolveOwnerUserId: () => 'uid-1',
      resolveClubId: () => 'club-1',
    );
    await sync.enqueueAfterStop('s1', dir: dir);
    await sync.retryManual();
    expect(gw.calls, 1);
    expect(sync.db.all().single.acked, isTrue);
  });

  test('3 rows outbox : 1 fail n’empêche pas les 2 autres ACK', () async {
    final root = await Directory.systemTemp.createTemp('datar0w_3row_');
    addTearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });

    Future<Directory> mk(String code) async {
      final d = Directory('${root.path}/$code');
      await d.create();
      await File('${d.path}/meta.json').writeAsString('{"code":"$code"}');
      await File('${d.path}/samples.jsonl').writeAsString('{}\n');
      return d;
    }

    final q = await mk('QEPSSL');
    final g = await mk('GT9JDK');
    final c = await mk('GCZEKF');

    final selective = _SelectiveGw(failCodes: {'QEPSSL'});
    sync = SessionSync(
      db: OutboxDb.memory(),
      gateway: selective,
      now: () => t,
      resolveOwnerUserId: () => 'uid-1',
      resolveClubId: () => 'club-1',
      ensureClub: () async => 'club-1',
    );
    await sync.enqueueAfterStop('QEPSSL', dir: q);
    await sync.enqueueAfterStop('GT9JDK', dir: g);
    await sync.enqueueAfterStop('GCZEKF', dir: c);
    await sync.retryManual();

    final byCode = {
      for (final r in sync.db.all()) r.path.split('/').last: r,
    };
    expect(byCode['QEPSSL']!.acked, isFalse);
    expect(byCode['QEPSSL']!.lastError, '42501');
    expect(byCode['GT9JDK']!.acked, isTrue);
    expect(byCode['GCZEKF']!.acked, isTrue);
    expect(selective.calls, 3);
  });
}

class _SelectiveGw implements TelemetryGateway {
  _SelectiveGw({required this.failCodes});
  final Set<String> failCodes;
  int calls = 0;

  @override
  Future<UploadResult> uploadAndUpsert({
    required OutboxRow row,
    required SessionPack pack,
    required Map<String, dynamic> meta,
  }) async {
    calls++;
    final code = row.path.split('/').last;
    if (failCodes.contains(code)) {
      return const UploadResult(ok: false, error: '42501');
    }
    return const UploadResult(ok: true, acked: true);
  }
}
