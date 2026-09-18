import 'package:datar0w/features/presession/screen_2a.dart';
import 'package:datar0w/session/boat_config.dart';
import 'package:datar0w/session/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classes 1x–8+ : sièges et cox, pas d’IMU extra', () {
    expect(BoatClassInfo.of('1x').seats, 1);
    expect(BoatClassInfo.of('1x').coxed, isFalse);
    expect(BoatClassInfo.of('2x').seats, 2);
    expect(BoatClassInfo.of('4-').seats, 4);
    expect(BoatClassInfo.of('4+').coxed, isTrue);
    expect(BoatClassInfo.of('8+').seats, 8);
    expect(BoatClassInfo.codes.length, 7);
  });

  test('siège borné à la classe ; changement de classe remet le siège', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(boatConfigProvider.notifier).setClasse('8+');
    container.read(boatConfigProvider.notifier).setSeat(7);
    expect(container.read(boatConfigProvider).classe, '8+');
    expect(container.read(boatConfigProvider).clampedSeat, 7);
    expect(container.read(boatConfigProvider).waitingSeats, [1, 2, 3, 4, 5, 6, 8]);
    container.read(boatConfigProvider.notifier).setClasse('2x');
    expect(container.read(boatConfigProvider).clampedSeat, 1);
    expect(container.read(boatConfigProvider).seats, 2);
    expect(container.read(boatConfigProvider).toMetaFields()['class'], '2x');
    expect(container.read(boatConfigProvider).toMetaFields()['seatIndex'], 1);
  });

  test('meta.json class + seats + cox + role + seatIndex survit au round-trip', () {
    const m = SessionMeta(
      id: 's1',
      classe: '8+',
      seats: 8,
      cox: true,
      role: 'rower',
      seatIndex: 4,
    );
    final j = m.toJson();
    expect(j['class'], '8+');
    expect(j['seats'], 8);
    expect(j['cox'], isTrue);
    expect(j['role'], 'rower');
    expect(j['seatIndex'], 4);
    final back = SessionMeta.fromJson(j);
    expect(back.classe, '8+');
    expect(back.seats, 8);
    expect(back.cox, isTrue);
    expect(back.role, 'rower');
    expect(back.seatIndex, 4);
  });

  testWidgets('2A : classe puis sièges de cette classe seulement', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PresessionScreen()),
      ),
    );
    expect(find.textContaining('1 · CLASSE'), findsOneWidget);
    expect(find.textContaining('2 · SIÈGE DANS 1X'), findsOneWidget);
    expect(find.text('1 nage'), findsOneWidget);
    expect(find.text('8'), findsNothing);

    await tester.tap(find.text('8+'));
    await tester.pump();
    expect(find.textContaining('2 · SIÈGE DANS 8+'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.textContaining('en attente'), findsOneWidget);
  });
}
