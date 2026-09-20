import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'layout_model.dart';

class LayoutStore {
  LayoutStore({Directory? root}) : _root = root;

  final Directory? _root;

  Future<Directory> _dir() async {
    if (_root != null) {
      await _root.create(recursive: true);
      return _root;
    }
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(docs.path, 'datar0w', 'layouts'));
    await d.create(recursive: true);
    return d;
  }

  Future<RowerLayout> load(String rowerId) async {
    final f = File(p.join((await _dir()).path, '$rowerId.json'));
    if (!f.existsSync()) return RowerLayout.security(rowerId);
    try {
      return RowerLayout.fromJson(
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
      );
    } catch (_) {
      return RowerLayout.security(rowerId);
    }
  }

  Future<void> save(RowerLayout layout) async {
    final f = File(p.join((await _dir()).path, '${layout.rowerId}.json'));
    await f.writeAsString(jsonEncode(layout.toJson()));
  }
}
