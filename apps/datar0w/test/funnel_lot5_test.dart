import 'dart:io';

import 'package:datar0w/funnel/controller.dart';
import 'package:datar0w/funnel/lot5_gates.dart';
import 'package:datar0w/funnel/lot5_models.dart';
import 'package:datar0w/funnel/lot5_store.dart';
import 'package:datar0w/funnel/models.dart';
import 'package:datar0w/funnel/store.dart';
import 'package:datar0w/identity/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ParkBoat _boat({
  required String id,
  String classe = '4x',
  int seats = 4,
  bool cox = false,
}) =>
    ParkBoat(
      id: id,
      clubId: 'c1',
      name: 'Test',
      classe: classe,
      seats: seats,
      cox: cox,
    );

Assignment _asg(String boatId, String rowerId, {String role = 'rower'}) =>
    Assignment.create(
      boatId: boatId,
      rowerId: rowerId,
      side: SidePref.none,
      seatIndex: role == 'cox' ? null : 1,
      role: role,
    );

void main() {
  test('skiff crew gate always complete', () {
    final boat = _boat(id: 'b1', classe: '1x', seats: 1);
    final r = evaluateCrewGate(boat: boat, assignments: const []);
    expect(r.complete, isTrue);
  });

  test('4x incomplete until 4 confirmed', () {
    final boat = _boat(id: 'b4');
    final asgs = [
      _asg('b4', 'r1'),
      _asg('b4', 'r2'),
      _asg('b4', 'r3'),
    ];
    final broken = evaluateCrewGate(boat: boat, assignments: asgs);
    expect(broken.complete, isFalse);
    expect(broken.confirmed, 3);
    expect(broken.canDownsize, isTrue);

    final full = evaluateCrewGate(
      boat: boat,
      assignments: [...asgs, _asg('b4', 'r4')],
    );
    expect(full.complete, isTrue);
  });

  test('water gate closed by veto', () {
    final now = DateTime.utc(2026, 10, 3, 12);
    final closures = [
      WaterClosure(
        id: 'v1',
        waterId: 'w1',
        from: now.subtract(const Duration(hours: 1)),
        to: now.add(const Duration(hours: 2)),
        reason: WaterVetoReason.vent,
      ),
    ];
    final closed = evaluateWaterGate(
      waterId: 'w1',
      closures: closures,
      at: now,
    );
    expect(closed.open, isFalse);
    expect(closed.closure?.reasonLine, contains('Vent'));

    final open = evaluateWaterGate(
      waterId: 'w2',
      closures: closures,
      at: now,
    );
    expect(open.open, isTrue);
  });

  test('resolve gates: water closed beats crew', () {
    final boat = _boat(id: 'b4');
    final plan = WaterOutingPlan(
      id: 'p',
      boatId: 'b4',
      boatClass: '4x',
      plannedAt: DateTime(2026, 10, 3, 18),
      distM: 2000,
      waterId: 'w1',
      seatsRequired: 4,
    );
    final now = DateTime.utc(2026, 10, 3, 12);
    final gate = resolveWaterGates(
      boat: boat,
      assignments: [
        _asg('b4', 'r1'),
        _asg('b4', 'r2'),
        _asg('b4', 'r3'),
        _asg('b4', 'r4'),
      ],
      plan: plan,
      closures: [
        WaterClosure(
          id: 'v1',
          waterId: 'w1',
          from: now.subtract(const Duration(hours: 1)),
          to: now.add(const Duration(hours: 2)),
          reason: WaterVetoReason.orage,
        ),
      ],
      at: now,
    );
    expect(gate.kind, WaterGateKind.waterClosed);
    expect(indoorCancelLabel(gate.kind), 'Eau annulée · plan d’eau');
  });

  test('erg replacement mapping', () {
    expect(
      ergReplacementForWater(
        waterDistM: 2000,
        frame: PracticeFrame.competition,
      ).id,
      'dist_2000',
    );
    expect(
      ergReplacementForWater(
        waterDistM: 6000,
        frame: PracticeFrame.loisir,
      ).id,
      'duration_30',
    );
    expect(
      ergReplacementForWater(
        waterDistM: 500,
        frame: PracticeFrame.sante,
      ).id,
      'duration_15',
    );
  });

  test('finishSession uses pendingOrigin remplacement', () async {
    final dir = Directory.systemTemp.createTempSync('funnel_lot5_');
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
    container.read(funnelProvider.notifier).setPendingOrigin('remplacement');
    final log = await container.read(funnelProvider.notifier).finishSession(
          piece: ErgPiece.distance2000,
          durationS: 440,
          complete: true,
        );
    expect(log.origin, 'remplacement');
    expect(container.read(funnelProvider).pendingOrigin, isNull);
  });

  test('lot5 store dispos + closures roundtrip', () async {
    final dir = Directory.systemTemp.createTempSync('lot5_store_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final store = Lot5Store(root: dir);
    await store.saveDispos([
      RowerDispo(
        rowerId: 'r1',
        day: localDayKey(),
        slot: DispoSlot.soir,
        mode: DispoMode.eau,
      ),
    ]);
    final loaded = await store.loadDispos();
    expect(loaded.single.mode, DispoMode.eau);

    await store.saveClosures([
      WaterClosure(
        id: 'c1',
        waterId: 'w1',
        from: DateTime.utc(2026, 10, 3),
        to: DateTime.utc(2026, 10, 4),
        reason: WaterVetoReason.crue,
      ),
    ]);
    expect((await store.loadClosures()).single.reason, WaterVetoReason.crue);
  });

  testWidgets('water closed harness shows erg CTA', (tester) async {
    final plan = WaterOutingPlan(
      id: 'p1',
      boatId: 'b4',
      boatClass: '4x',
      plannedAt: DateTime(2026, 10, 3, 18),
      distM: 2000,
      waterId: 'w1',
      waterLabel: 'Bassin test',
      seatsRequired: 4,
    );
    final now = DateTime.utc(2026, 10, 3, 12);
    final gate = resolveWaterGates(
      boat: _boat(id: 'b4'),
      assignments: [
        _asg('b4', 'r1'),
        _asg('b4', 'r2'),
        _asg('b4', 'r3'),
        _asg('b4', 'r4'),
      ],
      plan: plan,
      closures: [
        WaterClosure(
          id: 'v1',
          waterId: 'w1',
          from: now.subtract(const Duration(hours: 1)),
          to: now.add(const Duration(hours: 3)),
          reason: WaterVetoReason.vent,
        ),
      ],
      at: now,
    );
    expect(gate.kind, WaterGateKind.waterClosed);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _GateHarness(plan: plan, gate: gate),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Vent'), findsOneWidget);
    expect(find.textContaining('sur l’erg'), findsOneWidget);
  });
}

/// Affiche les mêmes libellés que la carte eau (sans identity seed).
class _GateHarness extends StatelessWidget {
  const _GateHarness({required this.plan, required this.gate});

  final WaterOutingPlan plan;
  final WaterGateResult gate;

  @override
  Widget build(BuildContext context) {
    final dist =
        ErgDistance.fromMeters(plan.distM)?.label ?? '${plan.distM} m';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(plan.headline),
          Text(gate.waterReason ?? ''),
          Text(indoorCancelLabel(gate.kind)),
          FilledButton(
            key: const Key('funnel-water-erg-closed'),
            onPressed: () {},
            child: Text('Faire le $dist sur l’erg'),
          ),
        ],
      ),
    );
  }
}
