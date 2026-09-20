import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

class LoisirStore {
  LoisirStore({this._root});
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
    return File(p.join(dir.path, 'participations_loisir.json'));
  }

  Future<List<ParticipationLoisir>> list() async {
    final f = await _file();
    if (!f.existsSync()) return [];
    final raw = jsonDecode(f.readAsStringSync());
    if (raw is! List) return [];
    return raw
        .map((e) => ParticipationLoisir.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(ParticipationLoisir p) async {
    final current = await list();
    current.removeWhere((e) => e.eventId == p.eventId && e.rowerId == p.rowerId);
    current.add(p);
    await (await _file()).writeAsString(
      jsonEncode(current.map((e) => e.toJson()).toList()),
    );
  }
}
