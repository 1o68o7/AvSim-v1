import 'dart:io';

import 'package:datar0w/funnel/controller.dart';
import 'package:datar0w/funnel/models.dart';
import 'package:datar0w/funnel/screen_onboard.dart';
import 'package:datar0w/funnel/screen_proof.dart';
import 'package:datar0w/funnel/store.dart';
import 'package:datar0w/onboarding/routing.dart';
import 'package:datar0w/identity/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('split = temps / distance × 500', () {
    expect(split500Seconds(durationS: 480, distM: 2000), closeTo(120, 1e-9));
    expect(split500Seconds(durationS: 90, distM: 500), closeTo(90, 1e-9));
    expect(split500Seconds(durationS: 0, distM: 2000), 0);
  });

  test('PB seulement sur 2000 complet', () async {
    final dir = Directory.systemTemp.createTempSync('funnel_pb_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final store = FunnelStore(root: dir);
    final partial = ErgSessionLog(
      distM: 2000,
      durationS: 420,
      split500S: split500Seconds(durationS: 420, distM: 2000),
      complete: false,
      at: DateTime.utc(2026, 10, 1),
    );
    final completeSlow = ErgSessionLog(
      distM: 2000,
      durationS: 500,
      split500S: split500Seconds(durationS: 500, distM: 2000),
      complete: true,
      at: DateTime.utc(2026, 10, 2),
    );
    final completeFast = ErgSessionLog(
      distM: 2000,
      durationS: 460,
      split500S: split500Seconds(durationS: 460, distM: 2000),
      complete: true,
      at: DateTime.utc(2026, 10, 3),
    );
    final only500 = ErgSessionLog(
      distM: 500,
      durationS: 90,
      split500S: 90,
      complete: true,
      at: DateTime.utc(2026, 10, 4),
    );

    expect(personalBestSeconds([partial], 2000), isNull);
    expect(personalBestSeconds([partial, completeSlow], 2000), 500);
    expect(
      personalBestSeconds([partial, completeSlow, completeFast], 2000),
      460,
    );
    expect(personalBestSeconds([only500], 2000), isNull);
    expect(
      isPersonalBest(log: partial, prior: const []),
      isFalse,
    );
    expect(
      isPersonalBest(log: completeSlow, prior: const []),
      isTrue,
    );
    expect(
      isPersonalBest(log: completeFast, prior: [completeSlow]),
      isTrue,
    );
    expect(
      isPersonalBest(log: completeSlow, prior: [completeFast]),
      isFalse,
    );

    await store.addLog(partial);
    await store.addLog(completeFast);
    final logs = await store.loadLogs();
    expect(personalBestSeconds(logs, 2000), 460);
  });

  test('needsLicence reste false', () {
    expect(needsLicence(const IdentitySnapshot()), isFalse);
  });

  testWidgets('promise screen CTA Commencer', (tester) async {
    final dir = Directory.systemTemp.createTempSync('funnel_ui_');
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
    expect(find.text('Commencer'), findsOneWidget);
    expect(
      find.textContaining('Un morceau déjà écrit'),
      findsOneWidget,
    );
  });

  testWidgets('proof shows time', (tester) async {
    final dir = Directory.systemTemp.createTempSync('funnel_proof_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final log = ErgSessionLog(
      distM: 2000,
      durationS: 464,
      split500S: split500Seconds(durationS: 464, distM: 2000),
      cadence: 28,
      watts: 220,
      dragFactor: 115,
      complete: true,
      at: DateTime.utc(2026, 10, 3),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          funnelStoreProvider.overrideWithValue(FunnelStore(root: dir)),
          funnelProvider.overrideWith(() => _SeededFunnel(log)),
        ],
        child: const MaterialApp(home: FunnelProofScreen()),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('funnel-proof-time')), findsOneWidget);
    expect(find.text(formatErgTime(464)), findsOneWidget);
    expect(find.text('Preuve'), findsOneWidget);
  });
}

class _SeededFunnel extends FunnelController {
  _SeededFunnel(this.log);
  final ErgSessionLog log;

  @override
  FunnelState build() => FunnelState(
        loaded: true,
        profile: const FunnelProfile(
          frame: PracticeFrame.competition,
          todayDistanceM: 2000,
          targetSplit500s: 120,
          onboardDone: true,
        ),
        logs: [log],
        lastResult: log,
        lastWasPb: true,
        activeDistM: 2000,
      );
}
