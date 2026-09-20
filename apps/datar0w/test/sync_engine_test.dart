import 'dart:io';

import 'package:datar0w/identity/models.dart';
import 'package:datar0w/identity/store.dart';
import 'package:datar0w/sync/identity_cloud.dart';
import 'package:datar0w/sync/lww.dart';
import 'package:datar0w/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LWW : le plus récent l’emporte', () {
    final t0 = DateTime.utc(2026, 1, 1);
    final t1 = DateTime.utc(2026, 1, 2);
    expect(remoteWins(t0, t1), isTrue);
    expect(remoteWins(t1, t0), isFalse);
    expect(
      pickLww(local: 'a', remote: 'b', localUpdated: t1, remoteUpdated: t0),
      'a',
    );
  });

  test('outbox + push + pull LWW', () async {
    final dir = await Directory.systemTemp.createTemp('datar0w-sync-');
    addTearDown(() => dir.delete(recursive: true));
    final store = IdentityStore(root: dir);
    final cloud = MemoryCloud();
    final engine = SyncEngine(
      store: store,
      outbox: await store.outbox(),
      cloud: cloud,
    );

    final club = Club.create(name: 'CNB', shortCode: 'CNB');
    await store.upsertClub(club);
    final pending = await (await store.outbox()).peek();
    expect(pending, isNotEmpty);
    expect(pending.first.table, 'clubs');

    await engine.push();
    expect(await (await store.outbox()).peek(), isEmpty);
    expect(cloud.tables['clubs']!.containsKey(club.id), isTrue);

    final older = Club(
      id: club.id,
      name: 'ancien',
      shortCode: 'OLD',
      createdAt: club.createdAt,
      updatedAt: club.updatedAt.subtract(const Duration(days: 1)),
    );
    cloud.tables['clubs']![club.id] = {
      'id': older.id,
      'name': older.name,
      'short_code': older.shortCode,
      'created_at': older.createdAt.toIso8601String(),
      'updated_at': older.updatedAt.toIso8601String(),
    };
    engine.lastSyncAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    await engine.pull();
    final kept = (await store.listClubs()).single;
    expect(kept.name, 'CNB');
  });
}
