import 'dart:io';

import 'package:datar0w/identity/ffa_categories.dart';
import 'package:datar0w/identity/is_lightweight.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/identity/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saison 2025-26 : 6 dates → catégories FFA', () {
    const y = 2025;
    expect(ageCategory(DateTime(2022, 3, 1), seasonYear: y).code, 'BB');
    expect(ageCategory(DateTime(2019, 6, 1), seasonYear: y).code, 'EA');
    expect(ageCategory(DateTime(2016, 1, 1), seasonYear: y).code, 'PO');
    expect(ageCategory(DateTime(2012, 8, 1), seasonYear: y).code, 'MI');
    expect(ageCategory(DateTime(2008, 12, 31), seasonYear: y).code, 'JU');
    expect(ageCategory(DateTime(1998, 4, 1), seasonYear: y).code, 'SE');
  });

  test('saison démarre au 1er septembre', () {
    expect(seasonStartYear(DateTime(2026, 8, 31)), 2025);
    expect(seasonStartYear(DateTime(2026, 9, 1)), 2026);
  });

  test('masters 1992 et avant en 2025-26', () {
    final c = ageCategory(DateTime(1990, 1, 1), seasonYear: 2025);
    expect(c.code, 'MA');
    expect(c.mastersBand, isNotNull);
  });

  test('poids léger H 72,5 / F 59', () {
    expect(isLightweight(sex: 'M', weightKg: 72.5), isTrue);
    expect(isLightweight(sex: 'M', weightKg: 72.6), isFalse);
    expect(isLightweight(sex: 'F', weightKg: 59), isTrue);
    expect(isLightweight(sex: 'F', weightKg: 59.1), isFalse);
    expect(isLightweight(sex: 'X', weightKg: 50), isFalse);
    expect(isLightweight(sex: 'M'), isFalse);
  });

  test('Rower / Club / Boat / Assignment JSON round-trip', () async {
    final dir = await Directory.systemTemp.createTemp('datar0w-id-');
    addTearDown(() => dir.delete(recursive: true));
    final store = IdentityStore(root: dir);

    final club = Club.create(name: 'CN Test', shortCode: 'CNT');
    await store.upsertClub(club);
    final rower = Rower.create(
      displayName: 'Ada Lovelace',
      birthDate: DateTime(1998, 5, 10),
      sex: RowerSex.f,
    ).copyWith(weightKg: 58, clubId: club.id);
    await store.upsertRower(rower);
    final boat = ParkBoat.create(
      clubId: club.id,
      name: 'Empacher',
      classe: '8+',
      oarRack: const ['P1', 'P2', 'P4'],
    );
    expect(boat.seats, 8);
    expect(boat.cox, isTrue);
    await store.upsertBoat(boat);
    final asg = Assignment.create(
      boatId: boat.id,
      rowerId: rower.id,
      side: SidePref.babord,
      seatIndex: 3,
      oars: const ['P2'],
    );
    await store.upsertAssignment(asg);

    final r2 = (await store.listRowers()).single;
    expect(r2.displayName, 'Ada Lovelace');
    expect(r2.sex, RowerSex.f);
    expect(r2.lightweight, isTrue);
    expect(r2.category(seasonYear: 2025).code, 'SE');
    expect((await store.listClubs()).single.shortCode, 'CNT');
    expect((await store.listBoats()).single.classe, '8+');
    final a2 = (await store.listAssignments()).single;
    expect(a2.seatIndex, 3);
    expect(a2.side, SidePref.babord);
    expect(a2.createdAt, isNotNull);
    expect(Assignment.fromJson(a2.toJson()).id, a2.id);

    await store.deleteRower(rower.id);
    expect(await store.listRowers(), isEmpty);
  });
}
