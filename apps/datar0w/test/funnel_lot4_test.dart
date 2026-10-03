import 'dart:io';

import 'package:datar0w/funnel/controller.dart';
import 'package:datar0w/funnel/models.dart';
import 'package:datar0w/funnel/screen_ateliers.dart';
import 'package:datar0w/funnel/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot4 catalog distances', () {
    expect(ErgPiece.lot4Catalog.length, 5);
    expect(
      ErgPiece.lot4Catalog.map((p) => p.logDistM).toList(),
      [5000, 6000, 10000, 21000, 42000],
    );
    expect(ErgPiece.byId('brevet_10km')?.label, 'Brevet 10 km');
    expect(ErgPiece.fromDistanceMeters(21000).id, 'brevet_21km');
    expect(ErgDistance.fromMeters(6000)?.label, '6 000 m');
    expect(ErgDistance.m10000.label, '10 km');
  });

  test('brevet unlock chain 2000 → 10 → 21 → 42', () {
    expect(isLot4Unlocked(ErgPiece.distance5000, const []), isTrue);
    expect(isLot4Unlocked(ErgPiece.distance6000, const []), isTrue);
    expect(isLot4Unlocked(ErgPiece.brevet10km, const []), isFalse);
    expect(isLot4Unlocked(ErgPiece.brevet21km, const []), isFalse);
    expect(isLot4Unlocked(ErgPiece.brevet42km, const []), isFalse);

    final after2000 = [
      ErgSessionLog(
        distM: 2000,
        durationS: 420,
        split500S: 105,
        complete: true,
        at: DateTime.utc(2026, 10, 3),
      ),
    ];
    expect(isLot4Unlocked(ErgPiece.brevet10km, after2000), isTrue);
    expect(isLot4Unlocked(ErgPiece.brevet21km, after2000), isFalse);

    final after10 = [
      ...after2000,
      ErgSessionLog(
        distM: 10000,
        durationS: 2400,
        split500S: 120,
        complete: true,
        pieceId: 'brevet_10km',
        at: DateTime.utc(2026, 10, 4),
      ),
    ];
    expect(isLot4Unlocked(ErgPiece.brevet21km, after10), isTrue);
    expect(isLot4Unlocked(ErgPiece.brevet42km, after10), isFalse);

    final after21 = [
      ...after10,
      ErgSessionLog(
        distM: 21000,
        durationS: 5400,
        split500S: 128.5,
        complete: true,
        pieceId: 'brevet_21km',
        at: DateTime.utc(2026, 10, 5),
      ),
    ];
    expect(isLot4Unlocked(ErgPiece.brevet42km, after21), isTrue);
  });

  test('formatErgTime uses h:mm:ss beyond 60 min', () {
    expect(formatErgTime(3661), '1:01:01');
    expect(formatErgTime(5400), '1:30:00');
  });

  test('finishSession logs brevet 10 km pieceId', () async {
    final dir = Directory.systemTemp.createTempSync('funnel_lot4_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final container = ProviderContainer(
      overrides: [
        funnelStoreProvider.overrideWithValue(FunnelStore(root: dir)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(funnelProvider.notifier).completeOnboard(
          const FunnelProfile(
            frame: PracticeFrame.competition,
            todayDistanceM: 2000,
            onboardDone: true,
          ),
        );
    await container.read(funnelProvider.notifier).finishSession(
          piece: ErgPiece.distance2000,
          durationS: 430,
          complete: true,
        );
    final log = await container.read(funnelProvider.notifier).finishSession(
          piece: ErgPiece.brevet10km,
          durationS: 2400,
          complete: true,
        );
    expect(log.pieceId, 'brevet_10km');
    expect(log.distM, 10000);
    expect(
      isLot4Unlocked(
        ErgPiece.brevet21km,
        container.read(funnelProvider).logs,
      ),
      isTrue,
    );
  });

  testWidgets('ateliers shows endurance section and locked 10 km',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('funnel_lot4_ui_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          funnelStoreProvider.overrideWithValue(FunnelStore(root: dir)),
        ],
        child: const MaterialApp(home: FunnelAteliersScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Endurance & brevets km'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('funnel-lot4-brevet_10km')),
      200,
    );
    await tester.pump();
    expect(find.text('Brevet 10 km'), findsOneWidget);
    expect(find.text('5 000 m'), findsOneWidget);
    expect(find.textContaining('Verrouillé'), findsWidgets);
    expect(find.textContaining('Débloque après un 2 000 m'), findsOneWidget);
  });
}
