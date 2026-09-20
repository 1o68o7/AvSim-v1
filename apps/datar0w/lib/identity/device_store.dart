import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'devices.dart';

class DeviceStore {
  DeviceStore({this._root});
  final Directory? _root;

  Future<File> _file() async {
    final dir = _root ??
        Directory(
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            'datar0w',
          ),
        );
    await dir.create(recursive: true);
    return File(p.join(dir.path, 'cardio_devices.json'));
  }

  Future<List<ConnectedDevice>> list() async {
    final f = await _file();
    if (!f.existsSync()) return [];
    final raw = jsonDecode(f.readAsStringSync());
    if (raw is! List) return [];
    return raw
        .map((e) => ConnectedDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsert(ConnectedDevice d) async {
    final current = await list();
    current.removeWhere((e) => e.id == d.id);
    if (d.isPrimary) {
      for (var i = 0; i < current.length; i++) {
        final e = current[i];
        if (e.rowerId == d.rowerId && e.isPrimary) {
          current[i] = ConnectedDevice(
            id: e.id,
            rowerId: e.rowerId,
            type: e.type,
            name: e.name,
            bleId: e.bleId,
            isPrimary: false,
            pairedAt: e.pairedAt,
            lastSeenAt: e.lastSeenAt,
            lastBattery: e.lastBattery,
          );
        }
      }
    }
    current.add(d);
    await (await _file()).writeAsString(
      jsonEncode(current.map((e) => e.toJson()).toList()),
    );
  }
}
