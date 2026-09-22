import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/onboarding/routing.dart';
import 'package:datar0w/router.dart';
import 'package:datar0w/sync/auth_google.dart';
import 'package:datar0w/sync/auth_session.dart';
import 'package:datar0w/sync/club_remote.dart';
import 'package:datar0w/sync/club_sql.dart';
import 'package:datar0w/import/rower_csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

void main() {
  test('créer un club pousse insertClub (pas d’outbox #50)', () async {
    final remote = MemoryClubRemote();
    final container = ProviderContainer(
      overrides: [identityStoreOverride(), clubRemoteOverride(remote)],
    );
    addTearDown(container.dispose);
    await container.read(identityProvider.notifier).createClubAsAdmin(
          name: 'CNB',
          shortCode: 'CNB',
        );
    expect(remote.insertClubCalls, 1);
    expect(remote.clubs.values.single.name, 'CNB');
    expect(
      container.read(identityProvider).prefs.clubRole,
      ClubMemberRole.admin,
    );
  });

  test('hydrateFromCloud pose club + rôle, ignore le défaut admin local',
      () async {
    final remote = MemoryClubRemote()
      ..membership = const RemoteMembership(
        clubId: 'club-cloud',
        role: 'coach',
      )
      ..clubs['club-cloud'] = const RemoteClub(
        id: 'club-cloud',
        name: 'Aviron Cloud',
        shortCode: 'CLD',
      );
    final container = ProviderContainer(
      overrides: [identityStoreOverride(), clubRemoteOverride(remote)],
    );
    addTearDown(container.dispose);
    await container.read(identityProvider.notifier).hydrateFromCloud('user-1');
    final snap = container.read(identityProvider);
    expect(snap.prefs.activeClubId, 'club-cloud');
    expect(snap.prefs.clubRole, ClubMemberRole.coach);
    expect(snap.clubs.single.name, 'Aviron Cloud');
    expect(
      destinationAfterAuth(
        door: OnboardingDoor.club,
        snap: snap,
        sessionUserId: 'user-1',
      ),
      AppRoutes.homeCoach,
    );
  });

  test('onboarding avec session rattache userId + upsert rameur si club',
      () async {
    final remote = MemoryClubRemote();
    final auth = AuthGoogle(backend: _UidBackend('u-ada'))
      ..sessionUserId = 'u-ada';
    final container = ProviderContainer(
      overrides: [
        identityStoreOverride(),
        clubRemoteOverride(remote),
        authGoogleProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    final n = container.read(identityProvider.notifier);
    await n.saveClub(Club.create(name: 'CNB', shortCode: 'CNB'));
    await n.completeRowerOnboarding(
      displayName: 'Ada',
      birthDate: DateTime.utc(1998, 1, 1),
      clubCode: 'CNB',
    );
    final rower = container.read(identityProvider).rowers.single;
    expect(rower.userId, 'u-ada');
    expect(remote.rowers, isNotEmpty);
    expect(remote.rowers.single['user_id'], 'u-ada');
    expect(remote.rowers.single['club_id'], rower.clubId);
  });

  test('approve join appelle le remote', () async {
    final remote = MemoryClubRemote();
    final container = ProviderContainer(
      overrides: [identityStoreOverride(), clubRemoteOverride(remote)],
    );
    addTearDown(container.dispose);
    final n = container.read(identityProvider.notifier);
    await n.createClubAsAdmin(name: 'A', shortCode: 'AAA');
    final req = await n.requestClubRole(
      code: 'AAA',
      role: ClubMemberRole.coach,
      userId: 'u-2',
    );
    await n.decideJoinRequest(req!, accept: true);
    expect(remote.approvals[req.id], isTrue);
  });

  test('sql : reserved → out (contrainte boats.status)', () {
    expect(sqlBoatStatus(BoatParkStatus.reserved), 'out');
    expect(sqlBoatStatus(BoatParkStatus.ready), 'ready');
  });

  test('saveBoat pousse upsertBoat', () async {
    final remote = MemoryClubRemote();
    final container = ProviderContainer(
      overrides: [identityStoreOverride(), clubRemoteOverride(remote)],
    );
    addTearDown(container.dispose);
    final n = container.read(identityProvider.notifier);
    await n.createClubAsAdmin(name: 'CNB', shortCode: 'CNB');
    final club = container.read(identityProvider).clubs.single;
    await n.saveBoat(
      ParkBoat.create(clubId: club.id, name: 'Empacher', classe: '8+'),
    );
    expect(remote.boats.single['name'], 'Empacher');
    expect(remote.boats.single['class'], '8+');
    expect(remote.boats.single['club_id'], club.id);
  });

  test('hydrate fusionne bateaux cloud absents en local', () async {
    final boat = ParkBoat.create(
      clubId: 'club-cloud',
      name: 'Filippi',
      classe: '4-',
    );
    final remote = MemoryClubRemote()
      ..membership = const RemoteMembership(
        clubId: 'club-cloud',
        role: 'intendant',
      )
      ..clubs['club-cloud'] = const RemoteClub(
        id: 'club-cloud',
        name: 'Cloud',
        shortCode: 'CLD',
      )
      ..park = RemotePark(boats: [boat]);
    final container = ProviderContainer(
      overrides: [identityStoreOverride(), clubRemoteOverride(remote)],
    );
    addTearDown(container.dispose);
    await container.read(identityProvider.notifier).hydrateFromCloud('u-1');
    final snap = container.read(identityProvider);
    expect(snap.boats.single.name, 'Filippi');
    expect(snap.prefs.clubRole, ClubMemberRole.intendant);
  });

  test('import rameurs pousse upsertRower si club actif', () async {
    final remote = MemoryClubRemote();
    final container = ProviderContainer(
      overrides: [identityStoreOverride(), clubRemoteOverride(remote)],
    );
    addTearDown(container.dispose);
    final n = container.read(identityProvider.notifier);
    await n.createClubAsAdmin(name: 'CNB', shortCode: 'CNB');
    await n.confirmImportRowers([
      ParsedRowerRow(
        line: 2,
        cells: const {},
        displayName: 'Camille',
        birthDate: DateTime.utc(1998, 5, 10),
        sex: RowerSex.f,
      ),
    ]);
    expect(remote.rowers, isNotEmpty);
    expect(remote.rowers.last['display_name'], 'Camille');
    expect(remote.rowers.last['club_id'], isNotNull);
  });
}

class _UidBackend implements AuthBackend {
  _UidBackend(this.uid);

  final String uid;

  @override
  Future<bool> startGoogle({required String redirectTo}) async => false;

  @override
  Future<void> startMagicLink({
    required String email,
    required String redirectTo,
  }) async {}

  @override
  Future<bool> recoverSession(Uri uri) async => true;

  @override
  String? currentUserId() => uid;
}
