import 'dart:io';

import 'package:datar0w/funnel/controller.dart';
import 'package:datar0w/funnel/models.dart';
import 'package:datar0w/funnel/screen_ateliers.dart';
import 'package:datar0w/funnel/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('announced 1000 band 990–1010', () {
    expect(announced1000InBand(990), isTrue);
    expect(announced1000InBand(1000), isTrue);
    expect(announced1000InBand(1010), isTrue);
    expect(announced1000InBand(989), isFalse);
    expect(announced1000InBand(1011), isFalse);
  });

  test('lot2 catalog has four named FFA pieces', () {
    expect(ErgPiece.lot2Catalog.length, 4);
    expect(
      ErgPiece.lot2Catalog.map((p) => p.id).toSet(),
      {
        'brevet_5min_18',
        'brevet_3x1min',
        'brevet_1000_annonce',
        'relay_4x500',
      },
    );
    expect(ErgPiece.relay4x500.logDistM, 2000);
    expect(ErgPiece.threeByOne.blockCadences, [18, 22, 26]);
    expect(ErgPiece.fiveMin18.targetCadence, 18);
  });

  test('PB never on duration atelier', () {
    final log = ErgSessionLog(
      distM: 0,
      durationS: 300,
      split500S: 0,
      complete: true,
      pieceId: ErgPiece.fiveMin18.id,
      at: DateTime.utc(2026, 10, 3),
    );
    expect(isPersonalBest(log: log, prior: const []), isFalse);
  });

  test('finishSession logs pieceId for relay', () async {
    final dir = Directory.systemTemp.createTempSync('funnel_lot2_');
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
    final log = await container.read(funnelProvider.notifier).finishSession(
          piece: ErgPiece.relay4x500,
          durationS: 420,
          complete: true,
        );
    expect(log.pieceId, 'relay_4x500');
    expect(log.distM, 2000);
    expect(log.complete, isTrue);
  });

  testWidgets('ateliers screen lists FFA pieces', (tester) async {
    final dir = Directory.systemTemp.createTempSync('funnel_ateliers_');
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
    expect(find.text('Ateliers brevet'), findsOneWidget);
    expect(find.text('5 min continu'), findsOneWidget);
    expect(find.text('3 × 1 min'), findsOneWidget);
    expect(find.text('1 000 m annoncé'), findsOneWidget);
    expect(find.text('Relais 4 × 500 m'), findsOneWidget);
  });
}
