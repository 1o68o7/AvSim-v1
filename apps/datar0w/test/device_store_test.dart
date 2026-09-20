import 'dart:io';

import 'package:datar0w/identity/device_store.dart';
import 'package:datar0w/identity/devices.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('devices JSON + un seul primaire', () async {
    final dir = Directory(
      '/tmp/datar0w-dev-${DateTime.now().microsecondsSinceEpoch}',
    );
    final store = DeviceStore(root: dir);
    await store.upsert(
      ConnectedDevice(
        id: 'a',
        rowerId: 'r1',
        type: DeviceType.chestStrap,
        name: 'Polar H10',
        isPrimary: true,
        pairedAt: DateTime.utc(2026, 9, 20),
      ),
    );
    await store.upsert(
      ConnectedDevice(
        id: 'b',
        rowerId: 'r1',
        type: DeviceType.armBand,
        name: 'Verity',
        isPrimary: true,
        pairedAt: DateTime.utc(2026, 9, 20),
      ),
    );
    final list = await store.list();
    expect(list.where((d) => d.isPrimary).length, 1);
    expect(list.singleWhere((d) => d.isPrimary).id, 'b');
  });
}
