import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum PatchSyncStatus { idle, pending, ok }

class PatchSyncStore {
  PatchSyncStore({this.root});
  final Directory? root;

  Future<File> _file() async {
    final dir = root ??
        Directory(
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            'datar0w',
          ),
        );
    await dir.create(recursive: true);
    return File(p.join(dir.path, 'patch_sync.json'));
  }

  Future<PatchSyncStatus> status() async {
    final f = await _file();
    if (!f.existsSync()) return PatchSyncStatus.idle;
    try {
      final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      return PatchSyncStatus.values.firstWhere(
        (e) => e.name == j['status'],
        orElse: () => PatchSyncStatus.idle,
      );
    } catch (_) {
      return PatchSyncStatus.idle;
    }
  }

  Future<void> markPending() => _write(PatchSyncStatus.pending);

  /// Mock jsonl flash → quai. Pas de hardware.
  Future<File> importMock() async {
    final dir = (await _file()).parent;
    final out = File(
      p.join(dir.path, 'patch_import_${DateTime.now().millisecondsSinceEpoch}.jsonl'),
    );
    await out.writeAsString(
      '${jsonEncode({
        't': DateTime.now().millisecondsSinceEpoch,
        'src': 'patch',
        'hr_bpm': 148,
        'note': 'mock flash',
      })}\n',
    );
    await _write(PatchSyncStatus.ok);
    return out;
  }

  Future<void> _write(PatchSyncStatus s) async {
    await (await _file()).writeAsString(
      jsonEncode({'status': s.name, 'at': DateTime.now().toUtc().toIso8601String()}),
    );
  }
}

final patchSyncStoreProvider = Provider<PatchSyncStore>((_) => PatchSyncStore());
