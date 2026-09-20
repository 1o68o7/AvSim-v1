import 'dart:io';

import 'package:datar0w/identity/models.dart';
import 'package:datar0w/identity/store.dart';
import 'package:datar0w/ops/oar_set.dart';
import 'package:datar0w/ops/service.dart';
import 'package:datar0w/ops/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory idDir;
  late Directory opsDir;
  late IdentityStore identity;
  late OpsStore ops;
  late OpsService svc;
  late Club club;
  late ParkBoat boat;
  late Rower rower;

  setUp(() async {
    idDir = await Directory.systemTemp.createTemp('datar0w-id-');
    opsDir = await Directory.systemTemp.createTemp('datar0w-ops-');
    identity = IdentityStore(root: idDir);
    ops = OpsStore(root: opsDir);
    svc = OpsService(identity: identity, ops: ops);
    club = Club.create(name: 'CN Test', shortCode: 'CNT');
    await identity.upsertClub(club);
    boat = ParkBoat.create(
      clubId: club.id,
      name: 'Empacher',
      classe: '8+',
      oarRack: const ['P1', 'P2', 'P4'],
    );
    await identity.upsertBoat(boat);
    rower = Rower.create(
      displayName: 'Ada',
      birthDate: DateTime(1998, 5, 10),
    );
    await identity.upsertRower(rower);
    await identity.upsertAssignment(
      Assignment.create(
        boatId: boat.id,
        rowerId: rower.id,
        side: SidePref.babord,
        seatIndex: 1,
        oars: const ['P2'],
      ),
    );
  });

  tearDown(() async {
    await idDir.delete(recursive: true);
    await opsDir.delete(recursive: true);
  });

  test('sortie puis retour : ready → reserved → ready', () async {
    expect(await svc.canCompose(boat.id), isTrue);
    final r = await svc.checkout(
      boatId: boat.id,
      coachId: 'coach-a',
      coachName: 'Coach A',
      items: const [OarItem(spec: 'P1', qty: 2), OarItem(spec: 'P2', qty: 2)],
      plannedEnd: DateTime(2026, 9, 20, 15, 30),
    );
    expect(r.ok, isTrue);
    expect((await identity.listBoats()).single.status, BoatParkStatus.reserved);
    expect(await svc.canCompose(boat.id), isFalse);
    final notices = await ops.listNotices();
    expect(notices.single.message, contains('sortie'));

    await svc.checkIn(outId: r.out!.id, oarsOk: true);
    expect((await identity.listBoats()).single.status, BoatParkStatus.ready);
    expect(await svc.canCompose(boat.id), isTrue);
    expect((await ops.listOuts()).single.oarsOk, isTrue);
  });

  test('file d’attente si 2e coach, pas de refus sec', () async {
    await svc.checkout(
      boatId: boat.id,
      coachId: 'coach-a',
      coachName: 'Coach A',
      plannedEnd: DateTime(2026, 9, 20, 15, 30),
    );
    final r2 = await svc.checkout(
      boatId: boat.id,
      coachId: 'coach-b',
      coachName: 'Coach B',
    );
    expect(r2.kind, CheckoutKind.queued);
    expect(r2.message.toLowerCase(), contains('réservée'));
    expect(r2.message, contains('15h30'));
    expect((await ops.listOuts()).where((o) => o.isActive).length, 1);
    expect((await ops.listQueue()).length, 1);
  });

  test('pelles manquantes au retour', () async {
    final r = await svc.checkout(
      boatId: boat.id,
      coachId: 'coach-a',
      coachName: 'Coach A',
      items: const [OarItem(spec: 'P4', qty: 1)],
    );
    final done = await svc.checkIn(
      outId: r.out!.id,
      oarsOk: false,
      missingNote: 'P4 absente',
    );
    expect(done!.oarsOk, isFalse);
    expect(done.oarsMissingNote, 'P4 absente');
  });

  test('jeu hors rack refusé', () async {
    final r = await svc.checkout(
      boatId: boat.id,
      coachId: 'coach-a',
      coachName: 'Coach A',
      items: const [OarItem(spec: 'P9', qty: 1)],
    );
    expect(r.kind, CheckoutKind.blocked);
  });

  test('pelles perso hors rack acceptées', () async {
    final r = await svc.checkout(
      boatId: boat.id,
      coachId: 'coach-a',
      coachName: 'Coach A',
      items: const [
        OarItem(spec: 'P1', qty: 1),
        OarItem(spec: 'perso-ada', qty: 1, source: OarSource.personal),
      ],
    );
    expect(r.ok, isTrue);
  });

  test('report impact → maintenance, non re-sortable', () async {
    await svc.reportImpact(
      boatId: boat.id,
      reportedBy: 'coach-a',
      note: 'fissure étrave',
      photoPath: '/tmp/impact.jpg',
    );
    expect(
      (await identity.listBoats()).single.status,
      BoatParkStatus.maintenance,
    );
    expect(await svc.canCheckout(boat.id), isFalse);
    final blocked = await svc.checkout(
      boatId: boat.id,
      coachId: 'coach-a',
      coachName: 'Coach A',
    );
    expect(blocked.kind, CheckoutKind.blocked);
    expect((await ops.listNotices()).last.message, contains('maintenance'));

    final id = (await ops.listImpacts()).single.id;
    await svc.clearImpact(id);
    expect((await identity.listBoats()).single.status, BoatParkStatus.ready);
    expect(await svc.canCheckout(boat.id), isTrue);
  });

  test('transfert de sortie', () async {
    final r = await svc.checkout(
      boatId: boat.id,
      coachId: 'coach-a',
      coachName: 'Coach A',
    );
    final t = await svc.transfer(outId: r.out!.id, toCoachId: 'coach-b');
    expect(t!.coachId, 'coach-b');
    expect(t.transferredFromCoachId, 'coach-a');
    expect(t.transferredAt, isNotNull);
  });
}
