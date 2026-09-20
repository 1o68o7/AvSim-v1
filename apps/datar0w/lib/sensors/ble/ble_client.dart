import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class BleScanHit {
  const BleScanHit({
    required this.id,
    required this.name,
    required this.rssi,
  });

  final String id;
  final String name;
  final int rssi;
}

/// Scan / GATT Heart Rate. Fake en CI, FBP sur téléphone.
abstract class BleHrClient {
  Stream<List<BleScanHit>> get hits;
  Future<bool> ensurePermission();
  Future<void> startScan({Duration timeout = const Duration(seconds: 8)});
  Future<void> stopScan();
  Future<bool> connect(
    String id, {
    required void Function(List<int> payload) onPayload,
  });
  Future<void> disconnect();
}

class FakeBleHrClient implements BleHrClient {
  FakeBleHrClient({
    this.grantPermission = true,
    this.connectOk = true,
    List<BleScanHit>? hits,
  }) : seedHits = hits ??
            const [
              BleScanHit(id: 'aa:bb:cc:dd:ee:01', name: 'Polar H10', rssi: -52),
              BleScanHit(id: 'aa:bb:cc:dd:ee:02', name: 'Garmin HRM', rssi: -71),
            ];

  final bool grantPermission;
  final bool connectOk;
  final List<BleScanHit> seedHits;
  final _hits = StreamController<List<BleScanHit>>.broadcast();
  void Function(List<int> payload)? _onPayload;

  @override
  Stream<List<BleScanHit>> get hits => _hits.stream;

  @override
  Future<bool> ensurePermission() async => grantPermission;

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 8)}) async {
    if (!grantPermission) return;
    _hits.add(seedHits);
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<bool> connect(
    String id, {
    required void Function(List<int> payload) onPayload,
  }) async {
    if (!connectOk || !grantPermission) return false;
    _onPayload = onPayload;
    onPayload(const [0x00, 72]);
    return true;
  }

  @override
  Future<void> disconnect() async {
    _onPayload = null;
  }

  void emitPayload(List<int> data) => _onPayload?.call(data);

  void dispose() => _hits.close();
}

final bleHrClientProvider = Provider<BleHrClient>(
  (ref) => FlutterBlueHrClient(),
);

class FlutterBlueHrClient implements BleHrClient {
  final _hits = StreamController<List<BleScanHit>>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSub;
  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _notifySub;

  static final Guid _hrs = Guid('180d');
  static final Guid _hrm = Guid('2a37');

  @override
  Stream<List<BleScanHit>> get hits => _hits.stream;

  @override
  Future<bool> ensurePermission() async {
    try {
      final scan = await Permission.bluetoothScan.request();
      final connect = await Permission.bluetoothConnect.request();
      if (scan.isGranted && connect.isGranted) return true;
      try {
        final legacy = await Permission.bluetooth.request();
        return legacy.isGranted;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 8)}) async {
    await stopScan();
    final found = <String, BleScanHit>{};
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final id = r.device.remoteId.str;
        final name = r.device.platformName.trim().isEmpty
            ? 'sans nom'
            : r.device.platformName.trim();
        found[id] = BleScanHit(id: id, name: name, rssi: r.rssi);
      }
      _hits.add(found.values.toList());
    });
    try {
      await FlutterBluePlus.startScan(
        withServices: [_hrs],
        timeout: timeout,
      );
    } catch (_) {
      _hits.add(const []);
    }
  }

  @override
  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  @override
  Future<bool> connect(
    String id, {
    required void Function(List<int> payload) onPayload,
  }) async {
    await disconnect();
    try {
      final device = BluetoothDevice.fromId(id);
      _device = device;
      await device.connect(timeout: const Duration(seconds: 12));
      final services = await device.discoverServices();
      for (final s in services) {
        if (s.uuid != _hrs) continue;
        for (final c in s.characteristics) {
          if (c.uuid != _hrm) continue;
          await c.setNotifyValue(true);
          _notifySub = c.lastValueStream.listen(onPayload);
          return true;
        }
      }
      await device.disconnect();
      _device = null;
      return false;
    } catch (_) {
      _device = null;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
  }
}
