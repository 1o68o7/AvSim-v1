import 'dart:io';

import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/device_store.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/identity/store.dart';
import 'package:datar0w/features/identity/screen_devices.dart';
import 'package:datar0w/sensors/ble/ble_client.dart';
import 'package:datar0w/sensors/ble/hr_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

class _RowerIdentity extends IdentityController {
  _RowerIdentity(this.rower);
  final Rower rower;

  @override
  IdentitySnapshot build() {
    return IdentitySnapshot(
      rowers: [rower],
      prefs: IdentityPrefs(activeRowerId: rower.id),
    );
  }
}

void main() {
  test('fake scan : nom + RSSI, connect ingest 8 bits', () async {
    final fake = FakeBleHrClient();
    List<BleScanHit> seen = const [];
    final sub = fake.hits.listen((h) => seen = h);
    expect(await fake.ensurePermission(), isTrue);
    await fake.startScan();
    await Future<void>.delayed(Duration.zero);
    expect(seen.map((e) => e.name), contains('Polar H10'));
    expect(seen.first.rssi, isNegative);
    late List<int> payload;
    final ok = await fake.connect(
      seen.first.id,
      onPayload: (p) => payload = p,
    );
    expect(ok, isTrue);
    expect(parseHeartRateMeasurement(payload).bpm, 72);
    await sub.cancel();
    fake.dispose();
  });

  test('permission refusée : pas de crash, scan vide', () async {
    final fake = FakeBleHrClient(grantPermission: false);
    expect(await fake.ensurePermission(), isFalse);
    await fake.startScan();
    final ok = await fake.connect('x', onPayload: (_) {});
    expect(ok, isFalse);
    fake.dispose();
  });

  testWidgets('/devices SCANNER liste Polar + RSSI', (tester) async {
    final dir = Directory(
      '/tmp/datar0w-ble-${DateTime.now().microsecondsSinceEpoch}',
    );
    final rower = Rower.create(
      displayName: 'Camille',
      birthDate: DateTime(1998, 5, 10),
    );
    final fake = FakeBleHrClient();
    addTearDown(fake.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          identityProvider.overrideWith(() => _RowerIdentity(rower)),
          deviceStoreProvider.overrideWith((_) => DeviceStore(root: dir)),
          bleHrClientProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: DevicesScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('♥ —'), findsOneWidget);
    await tester.tap(find.textContaining('SCAN'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Polar H10'), findsOneWidget);
    expect(find.textContaining('RSSI'), findsWidgets);
  });

  testWidgets('refus BLE → chip ♥ —', (tester) async {
    final dir = Directory(
      '/tmp/datar0w-ble-deny-${DateTime.now().microsecondsSinceEpoch}',
    );
    final rower = Rower.create(
      displayName: 'Camille',
      birthDate: DateTime(1998, 5, 10),
    );
    final fake = FakeBleHrClient(grantPermission: false);
    addTearDown(fake.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          identityProvider.overrideWith(() => _RowerIdentity(rower)),
          deviceStoreProvider.overrideWith((_) => DeviceStore(root: dir)),
          bleHrClientProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: DevicesScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('SCAN'));
    await tester.pump();
    expect(find.text('♥ —'), findsWidgets);
    expect(find.textContaining('Bluetooth refusé'), findsOneWidget);
  });
}
