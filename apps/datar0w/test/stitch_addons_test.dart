import 'dart:convert';
import 'dart:io';

import 'package:datar0w/calendar/models.dart';
import 'package:datar0w/features/live/screen_3.dart';
import 'package:datar0w/features/presession/screen_2a.dart';
import 'package:datar0w/features/quai/screen_7.dart';
import 'package:datar0w/identity/device_store.dart';
import 'package:datar0w/identity/devices.dart';
import 'package:datar0w/identity/patch_sync.dart';
import 'package:datar0w/router.dart';
import 'package:datar0w/sensors/ble/hr_parser.dart';
import 'package:datar0w/session/boat_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

void main() {
  test('DeviceStore upsert patch + feedback persistés', () async {
    final dir = Directory(
      '/tmp/datar0w-patch-${DateTime.now().microsecondsSinceEpoch}',
    );
    final store = DeviceStore(root: dir);
    await store.upsert(
      ConnectedDevice(
        id: 'p1',
        rowerId: 'r1',
        type: DeviceType.patchDorsal,
        name: 'Patch dorsal',
        isPrimary: false,
        pairedAt: DateTime.utc(2026, 9, 21),
        lastBattery: 80,
        patchLink: PatchLinkState.paired,
        feedbackCadence: true,
        feedbackGite: true,
      ),
    );
    final d = (await store.list()).single;
    expect(d.isPatch, isTrue);
    expect(d.feedbackCadence, isTrue);
    expect(d.feedbackGite, isTrue);
    expect(d.feedbackHr, isFalse);
    expect(d.patchLink, PatchLinkState.paired);
    expect(ConnectedDevice.fromJson(d.toJson()).feedbackCadence, isTrue);
  });

  test('water_id uby-cazaubon résolu', () {
    final ev = jsonDecode(
      File('assets/ffa_calendar_2026.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final waters = jsonDecode(
      File('assets/waters.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final events = (ev['events'] as List)
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    final ids = (waters['waters'] as List)
        .map((e) => (e as Map)['id'] as String)
        .toSet();
    expect(ids.contains('uby-cazaubon'), isTrue);
    expect(ids.contains('ubarritz-cazaubon'), isFalse);
    final caza = events.firstWhere((e) => e.id.contains('cazaubon'));
    expect(caza.waterId, 'uby-cazaubon');
    expect(ids.contains(caza.waterId), isTrue);
  });

  test('parser HR 8/16 inchangé', () {
    expect(parseHeartRateMeasurement([0x00, 72]).bpm, 72);
    expect(parseHeartRateMeasurement([0x01, 0x2C, 0x01]).bpm, 300);
  });

  test('routes gelées toujours listées', () {
    expect(AppRoutes.devices, '/devices');
    expect(AppRoutes.presession, '/presession');
    expect(AppRoutes.live, '/live');
    expect(AppRoutes.quai, '/quai');
    expect(AppRoutes.calendar, '/calendar');
  });

  test('PatchSyncStore mock jsonl', () async {
    final dir = Directory(
      '/tmp/datar0w-psync-${DateTime.now().microsecondsSinceEpoch}',
    );
    final store = PatchSyncStore(root: dir);
    expect(await store.status(), PatchSyncStatus.idle);
    await store.markPending();
    expect(await store.status(), PatchSyncStatus.pending);
    final f = await store.importMock();
    expect(f.existsSync(), isTrue);
    expect(await store.status(), PatchSyncStatus.ok);
  });

  testWidgets('/presession sélecteur de mode', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PresessionScreen())),
    );
    expect(find.text('ENTRAÎNEMENT'), findsOneWidget);
    expect(find.text('COMPÉTITION'), findsOneWidget);
    await tester.tap(find.text('COMPÉTITION'));
    await tester.pump();
    expect(find.textContaining('tel au quai'), findsOneWidget);
  });

  testWidgets('/live compétition : bandeau, pas de crash sans GPS', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dir = Directory(
      '/tmp/datar0w-live-${DateTime.now().microsecondsSinceEpoch}',
    );
    final container = ProviderContainer(
      overrides: [
        identityStoreOverride(),
        deviceStoreProvider.overrideWith((_) => DeviceStore(root: dir)),
      ],
    );
    addTearDown(container.dispose);
    container.read(boatConfigProvider.notifier).setSessionMode(
          SessionMode.competition,
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LiveScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('tel au quai'), findsOneWidget);
    expect(find.text('♥ —'), findsOneWidget);
    expect(find.textContaining('STOP'), findsOneWidget);
  });

  testWidgets('/quai Importer patch', (tester) async {
    final dir = Directory(
      '/tmp/datar0w-quai-${DateTime.now().microsecondsSinceEpoch}',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          patchSyncStoreProvider.overrideWith((_) => PatchSyncStore(root: dir)),
        ],
        child: const MaterialApp(home: QuaiScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('IMPORTER PATCH'), findsOneWidget);
    expect(find.text('PARTAGER AU COACH'), findsOneWidget);
    expect(dir.path, isNotEmpty);
  });
}
