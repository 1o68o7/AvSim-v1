import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'boat_out.dart';
import 'impact_report.dart';
import 'oar_set.dart';

/// CRUD JSON sous `Documents/datar0w/ops/`.
class OpsStore {
  OpsStore({Directory? root}) : _rootOverride = root;

  final Directory? _rootOverride;

  Future<Directory> root() async {
    if (_rootOverride != null) {
      await _rootOverride.create(recursive: true);
      return _rootOverride;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'datar0w', 'ops'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<List<BoatOut>> listOuts() async {
    final raw = await _readList('boat_outs.json');
    return raw.map(BoatOut.fromJson).toList();
  }

  Future<void> upsertOut(BoatOut row) async {
    final list = await listOuts();
    final i = list.indexWhere((e) => e.id == row.id);
    if (i >= 0) {
      list[i] = row;
    } else {
      list.add(row);
    }
    await _writeList('boat_outs.json', list.map((e) => e.toJson()).toList());
  }

  Future<List<OarSet>> listOarSets() async {
    final raw = await _readList('oar_sets.json');
    return raw.map(OarSet.fromJson).toList();
  }

  Future<void> upsertOarSet(OarSet row) async {
    final list = await listOarSets();
    final i = list.indexWhere((e) => e.id == row.id);
    if (i >= 0) {
      list[i] = row;
    } else {
      list.add(row);
    }
    await _writeList('oar_sets.json', list.map((e) => e.toJson()).toList());
  }

  Future<List<ImpactReport>> listImpacts() async {
    final raw = await _readList('impact_reports.json');
    return raw.map(ImpactReport.fromJson).toList();
  }

  Future<void> upsertImpact(ImpactReport row) async {
    final list = await listImpacts();
    final i = list.indexWhere((e) => e.id == row.id);
    if (i >= 0) {
      list[i] = row;
    } else {
      list.add(row);
    }
    await _writeList(
      'impact_reports.json',
      list.map((e) => e.toJson()).toList(),
    );
  }

  Future<List<QueueEntry>> listQueue() async {
    final raw = await _readList('queue.json');
    return raw.map(QueueEntry.fromJson).toList();
  }

  Future<void> upsertQueue(QueueEntry row) async {
    final list = await listQueue();
    final i = list.indexWhere((e) => e.id == row.id);
    if (i >= 0) {
      list[i] = row;
    } else {
      list.add(row);
    }
    await _writeList('queue.json', list.map((e) => e.toJson()).toList());
  }

  Future<void> removeQueueForBoat(String boatId) async {
    final list = await listQueue();
    list.removeWhere((e) => e.boatId == boatId);
    await _writeList('queue.json', list.map((e) => e.toJson()).toList());
  }

  Future<List<OpsNotice>> listNotices() async {
    final raw = await _readList('notices.json');
    return raw.map(OpsNotice.fromJson).toList();
  }

  Future<void> upsertNotice(OpsNotice row) async {
    final list = await listNotices();
    final i = list.indexWhere((e) => e.id == row.id);
    if (i >= 0) {
      list[i] = row;
    } else {
      list.add(row);
    }
    await _writeList('notices.json', list.map((e) => e.toJson()).toList());
  }

  Future<void> writeOutbox(List<Map<String, dynamic>> rows) async {
    final dir = await root();
    await File(p.join(dir.path, 'outbox.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(rows),
    );
  }

  Future<List<Map<String, dynamic>>> readOutbox() async {
    return _readList('outbox.json');
  }

  Future<List<Map<String, dynamic>>> _readList(String name) async {
    final dir = await root();
    final f = File(p.join(dir.path, name));
    if (!f.existsSync()) return [];
    final raw = jsonDecode(await f.readAsString());
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _writeList(String name, List<Map<String, dynamic>> rows) async {
    final dir = await root();
    await File(p.join(dir.path, name)).writeAsString(
      const JsonEncoder.withIndent('  ').convert(rows),
    );
  }

  List<BoatOut>? tryListOutsSync() {
    final raw = _tryReadListSync('boat_outs.json');
    return raw?.map(BoatOut.fromJson).toList();
  }

  List<OarSet>? tryListOarSetsSync() {
    final raw = _tryReadListSync('oar_sets.json');
    return raw?.map(OarSet.fromJson).toList();
  }

  List<ImpactReport>? tryListImpactsSync() {
    final raw = _tryReadListSync('impact_reports.json');
    return raw?.map(ImpactReport.fromJson).toList();
  }

  List<QueueEntry>? tryListQueueSync() {
    final raw = _tryReadListSync('queue.json');
    return raw?.map(QueueEntry.fromJson).toList();
  }

  List<OpsNotice>? tryListNoticesSync() {
    final raw = _tryReadListSync('notices.json');
    return raw?.map(OpsNotice.fromJson).toList();
  }

  List<Map<String, dynamic>>? _tryReadListSync(String name) {
    final dir = _rootOverride;
    if (dir == null) return null;
    dir.createSync(recursive: true);
    final f = File(p.join(dir.path, name));
    if (!f.existsSync()) return [];
    final raw = jsonDecode(f.readAsStringSync());
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
