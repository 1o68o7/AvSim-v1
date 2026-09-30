import 'dart:io';

import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/store.dart';
import 'package:datar0w/router.dart';
import 'package:datar0w/session/session_pack.dart';
import 'package:datar0w/session/session_sync.dart';
import 'package:datar0w/sync/club_remote.dart';
import 'package:datar0w/sync/outbox_db.dart';
import 'package:datar0w/sync/sync_identity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

class _Gw implements TelemetryGateway {
  int calls = 0;
  bool ack = true;

  @override
  Future<UploadResult> uploadAndUpsert({
    required OutboxRow row,
    required SessionPack pack,
    required Map<String, dynamic> meta,
  }) async {
    calls++;
    if (!ack) return const UploadResult(ok: false, error: 'nack');
    return const UploadResult(ok: true, acked: true);
  }
}

void main() {
  late Directory idDir;

  setUp(() {
    debugResetActiveClubIdMemory();
    IdentityStore.debugResetResolvedRoot();
    idDir = newIdentityDir();
  });

  tearDown(() {
    debugResetActiveClubIdMemory();
    IdentityStore.debugResetResolvedRoot();
    if (idDir.existsSync()) idDir.deleteSync(recursive: true);
  });

  test('uid + 1 membership + activeClubId null → ensure pose l’id', () async {
    const clubId = '169c88f1-8627-4e6e-a757-9b225c568771';
    final store = IdentityStore(root: idDir);
    final remote = MemoryClubRemote()
      ..membership = const RemoteMembership(
        clubId: clubId,
        role: 'admin',
      )
      ..clubs[clubId] = const RemoteClub(
        id: clubId,
        name: 'Bordeaux',
        shortCode: 'BDX',
      );

    expect(await store.loadState().then((p) => p.activeClubId), isNull);
    expect(defaultActiveClubId(), isNull);

    final posed = await ensureActiveClubForSync(
      store: store,
      remote: remote,
      resolveOwnerUserId: () => '143623bb-577b-4efc-ab39-154a6ecd2de8',
    );
    expect(posed, clubId);
    expect((await store.loadState()).activeClubId, clubId);
    expect(defaultActiveClubId(), clubId);
    expect(remote.insertClubCalls, 0);
  });

  test('hasAuthAndClub true après ensure (uid + club mémoire)', () async {
    const clubId = '169c88f1-8627-4e6e-a757-9b225c568771';
    final store = IdentityStore(root: idDir);
    final remote = MemoryClubRemote()
      ..membership = const RemoteMembership(clubId: clubId, role: 'admin')
      ..clubs[clubId] = const RemoteClub(id: clubId, name: 'Bordeaux');

    await ensureActiveClubForSync(
      store: store,
      remote: remote,
      resolveOwnerUserId: () => '143623bb-577b-4efc-ab39-154a6ecd2de8',
    );

    final sync = SessionSync(
      db: OutboxDb.memory(),
      gateway: _Gw(),
      resolveOwnerUserId: () => '143623bb-577b-4efc-ab39-154a6ecd2de8',
      // Lit defaultActiveClubId (mémoire) — pas d’inject club.
    );
    addTearDown(sync.db.dispose);
    expect(sync.hasAuthAndClub, isTrue);
  });

  test('hydrateFromCloud via controller pose club + notify', () async {
    const clubId = '169c88f1-8627-4e6e-a757-9b225c568771';
    final remote = MemoryClubRemote()
      ..membership = const RemoteMembership(clubId: clubId, role: 'admin')
      ..clubs[clubId] = const RemoteClub(id: clubId, name: 'Bordeaux');
    final container = ProviderContainer(
      overrides: [
        identityStoreOverride(root: idDir),
        clubRemoteOverride(remote),
      ],
    );
    addTearDown(container.dispose);

    expect(defaultActiveClubId(), isNull);
    await container
        .read(identityProvider.notifier)
        .hydrateFromCloud('143623bb-577b-4efc-ab39-154a6ecd2de8');
    expect(container.read(identityProvider).prefs.activeClubId, clubId);
    expect(defaultActiveClubId(), clubId);
  });

  test('sans membership → ensure null, pas de 2e club', () async {
    final store = IdentityStore(root: idDir);
    final remote = MemoryClubRemote(); // membership null
    final posed = await ensureActiveClubForSync(
      store: store,
      remote: remote,
      resolveOwnerUserId: () => 'uid-orphan',
    );
    expect(posed, isNull);
    expect((await store.loadState()).activeClubId, isNull);
    expect(remote.insertClubCalls, 0);
    expect(defaultActiveClubId(), isNull);
  });

  test('sans membership → retryManual lastError pas de club', () async {
    final dir = await Directory.systemTemp.createTemp('datar0w_club_err_');
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    await File('${dir.path}/meta.json').writeAsString('{"id":"QEPSSL"}');
    await File('${dir.path}/samples.jsonl').writeAsString('{}\n');

    final store = IdentityStore(root: idDir);
    final remote = MemoryClubRemote();
    final gw = _Gw()..ack = false;
    final posed = await ensureActiveClubForSync(
      store: store,
      remote: remote,
      resolveOwnerUserId: () => 'uid-1',
    );
    expect(posed, isNull);

    final sync = SessionSync(
      db: OutboxDb.memory(),
      gateway: gw,
      now: () => DateTime.utc(2026, 9, 30, 12),
      resolveOwnerUserId: () => 'uid-1',
      resolveClubId: () => defaultActiveClubId(),
      ensureClub: () async => null,
    );
    addTearDown(sync.db.dispose);
    await sync.enqueueAfterStop('QEPSSL', dir: dir);
    await sync.retryManual();
    expect(sync.db.all().single.lastError, 'pas de club');
    expect(sync.db.all().single.acked, isFalse);
    expect(AppRoutes.clubJoin, '/club/join');
  });

  test('CTA club join route = /club/join', () {
    expect(AppRoutes.clubJoin, '/club/join');
    expect(AppRoutes.club, '/club');
  });
}
