import 'dart:io';

import 'package:datar0w/funnel/controller.dart';
import 'package:datar0w/funnel/models.dart';
import 'package:datar0w/funnel/screen_onboard.dart';
import 'package:datar0w/funnel/screen_proof.dart';
import 'package:datar0w/funnel/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('onboard shows Importer ma licence', (tester) async {
    final dir = Directory.systemTemp.createTempSync('reste_onboard_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          funnelStoreProvider.overrideWithValue(FunnelStore(root: dir)),
        ],
        child: const MaterialApp(home: FunnelOnboardScreen()),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('funnel-onboard-import-license')), findsOneWidget);
    expect(find.text('Importer ma licence'), findsOneWidget);
  });

  testWidgets('proof shows Garder ce temps', (tester) async {
    final dir = Directory.systemTemp.createTempSync('reste_proof_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final log = ErgSessionLog(
      distM: 2000,
      durationS: 480,
      split500S: 120,
      cadence: 28,
      watts: 220,
      dragFactor: 110,
      complete: true,
      at: DateTime.utc(2026, 10, 3),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          funnelStoreProvider.overrideWithValue(FunnelStore(root: dir)),
          funnelProvider.overrideWith(() => _Seeded(log)),
        ],
        child: const MaterialApp(home: FunnelProofScreen()),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('funnel-proof-keep')), findsOneWidget);
    expect(find.text('Garder ce temps'), findsOneWidget);
  });
}

class _Seeded extends FunnelController {
  _Seeded(this.log);
  final ErgSessionLog log;

  @override
  FunnelState build() => FunnelState(
        loaded: true,
        logs: [log],
        lastResult: log,
        profile: const FunnelProfile(
          frame: PracticeFrame.competition,
          todayDistanceM: 2000,
          onboardDone: true,
        ),
      );
}
