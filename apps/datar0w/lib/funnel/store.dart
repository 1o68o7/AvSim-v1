import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Prefs + logs funnel en local (JSON). Pas de table erg_logs.
class FunnelStore {
  FunnelStore({Directory? root}) : _root = root;

  final Directory? _root;

  Future<Directory> _dir() async {
    final dir = _root ??
        Directory(
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            'datar0w',
          ),
        );
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> _prefsFile() async =>
      File(p.join((await _dir()).path, 'funnel_prefs.json'));

  Future<File> _logsFile() async =>
      File(p.join((await _dir()).path, 'funnel_logs.json'));

  Future<FunnelProfile?> loadProfile() async {
    final f = await _prefsFile();
    if (!f.existsSync()) return null;
    final raw = jsonDecode(f.readAsStringSync());
    if (raw is! Map<String, dynamic>) return null;
    return FunnelProfile.fromJson(raw);
  }

  Future<void> saveProfile(FunnelProfile profile) async {
    await (await _prefsFile()).writeAsString(jsonEncode(profile.toJson()));
  }

  Future<List<ErgSessionLog>> loadLogs() async {
    final f = await _logsFile();
    if (!f.existsSync()) return const [];
    final raw = jsonDecode(f.readAsStringSync());
    if (raw is! List) return const [];
    return raw
        .map((e) => ErgSessionLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveLogs(List<ErgSessionLog> logs) async {
    await (await _logsFile()).writeAsString(
      jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addLog(ErgSessionLog log) async {
    final logs = await loadLogs();
    logs.add(log);
    await saveLogs(logs);
  }

  /// Nombre de séances déjà jouées sur [distM] (complètes ou partielles).
  Future<int> sessionCountForDistance(int distM) async {
    final logs = await loadLogs();
    return logs.where((l) => l.distM == distM).length;
  }

  Future<void> clear() async {
    final prefs = await _prefsFile();
    final logs = await _logsFile();
    if (prefs.existsSync()) await prefs.delete();
    if (logs.existsSync()) await logs.delete();
  }
}
