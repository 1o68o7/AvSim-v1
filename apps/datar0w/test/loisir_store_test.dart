import 'dart:io';

import 'package:datar0w/calendar/loisir_store.dart';
import 'package:datar0w/calendar/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signalement participation JSON, 1 par événement', () async {
    final dir = Directory(
      '/tmp/datar0w-loi-${DateTime.now().microsecondsSinceEpoch}',
    );
    final store = LoisirStore(root: dir);
    final p = ParticipationLoisir(
      id: '1',
      eventId: 'e1',
      rowerId: 'r1',
      type: 'randonnee',
      date: DateTime.utc(2026, 3, 21),
      distanceKm: 27,
    );
    await store.add(p);
    await store.add(p.copyWithTime('1:05:59'));
    final list = await store.list();
    expect(list.length, 1);
    expect(list.single.tempsCourse, '1:05:59');
  });
}

extension on ParticipationLoisir {
  ParticipationLoisir copyWithTime(String t) => ParticipationLoisir(
        id: id,
        eventId: eventId,
        rowerId: rowerId,
        type: type,
        date: date,
        tempsCourse: t,
        distanceKm: distanceKm,
        classementLoisir: classementLoisir,
        source: source,
      );
}
