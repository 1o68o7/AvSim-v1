import 'dart:io';

import 'package:datar0w/funnel/logbook_export.dart';
import 'package:datar0w/funnel/models.dart';
import 'package:datar0w/funnel/pm5_client.dart';
import 'package:datar0w/funnel/screen_pm5.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logbook CSV has header and row', () {
    final log = ErgSessionLog(
      distM: 2000,
      durationS: 464,
      split500S: 116,
      cadence: 28,
      watts: 220,
      dragFactor: 118,
      complete: true,
      pieceId: ErgPiece.distance2000.id,
      at: DateTime.utc(2026, 10, 3, 12),
    );
    final csv = LogbookExport.toCsv([log]);
    expect(csv.split('\n').first, contains('drag_factor'));
    expect(csv, contains('2000'));
    expect(csv, contains('118'));
    expect(csv, contains('dist_2000'));
  });

  test('logbook writeFiles creates csv+json', () async {
    final dir = Directory.systemTemp.createTempSync('logbook_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final log = ErgSessionLog(
      distM: 500,
      durationS: 90,
      split500S: 90,
      complete: true,
      at: DateTime.utc(2026, 10, 3),
    );
    final csv = await LogbookExport.writeFiles([log], root: dir);
    expect(csv.existsSync(), isTrue);
    expect(csv.readAsStringSync(), contains('500'));
    final jsons = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));
    expect(jsons.length, 1);
  });

  test('FakePm5Client connect exposes live DF', () async {
    final client = FakePm5Client(seedDragFactor: 115);
    addTearDown(client.dispose);
    final ticks = <Pm5LiveTick>[];
    final sub = client.ticks.listen(ticks.add);
    addTearDown(sub.cancel);
    expect(await client.connect('c2-48291'), isTrue);
    expect(client.lastDragFactor, 115);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(ticks, isNotEmpty);
    expect(ticks.first.dragFactor, 115);

    await client.startWorkout(targetDistM: 500);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await client.stopWorkout();
    expect(ticks.length, greaterThan(1));
    expect(ticks.last.distM, greaterThan(0));
    expect(ticks.last.split500S, greaterThan(0));
  });

  testWidgets('PM5 screen lists devices and Relier', (tester) async {
    final client = FakePm5Client();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pm5ClientProvider.overrideWithValue(client),
        ],
        child: const MaterialApp(home: FunnelPm5Screen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('PM5'), findsOneWidget);
    expect(find.textContaining('Drag factor live'), findsOneWidget);
    expect(find.textContaining('PM5 · C2-48291'), findsOneWidget);
    await tester.tap(find.text('Relier').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('funnel-pm5-connected')), findsOneWidget);
    expect(find.textContaining('DF'), findsWidgets);
  });
}
