import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'lot5_models.dart';

/// Prefs locales dispos / veto / plan eau. Pas de table cloud Lot 5.
class Lot5Store {
  Lot5Store({Directory? root}) : _root = root;

  final Directory? _root;

  Future<Directory> _dir() async {
    final dir = _root ??
        Directory(
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            'datar0w',
            'lot5',
          ),
        );
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String name) async =>
      File(p.join((await _dir()).path, name));

  Future<List<RowerDispo>> loadDispos() async {
    final f = await _file('dispos.json');
    if (!f.existsSync()) return const [];
    final text = f.readAsStringSync().trim();
    if (text.isEmpty) return const [];
    try {
      final raw = jsonDecode(text);
      if (raw is! List) return const [];
      return raw
          .map((e) => RowerDispo.fromJson(e as Map<String, dynamic>))
          .toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> saveDispos(List<RowerDispo> dispos) async {
    await (await _file('dispos.json')).writeAsString(
      jsonEncode(dispos.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<WaterClosure>> loadClosures() async {
    final f = await _file('closures.json');
    if (!f.existsSync()) return const [];
    final text = f.readAsStringSync().trim();
    if (text.isEmpty) return const [];
    try {
      final raw = jsonDecode(text);
      if (raw is! List) return const [];
      return raw
          .map((e) => WaterClosure.fromJson(e as Map<String, dynamic>))
          .toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> saveClosures(List<WaterClosure> closures) async {
    await (await _file('closures.json')).writeAsString(
      jsonEncode(closures.map((e) => e.toJson()).toList()),
    );
  }

  Future<WaterOutingPlan?> loadPlan() async {
    final f = await _file('plan.json');
    if (!f.existsSync()) return null;
    final text = f.readAsStringSync().trim();
    if (text.isEmpty) return null;
    try {
      final raw = jsonDecode(text);
      if (raw is! Map<String, dynamic>) return null;
      return WaterOutingPlan.fromJson(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> savePlan(WaterOutingPlan? plan) async {
    final f = await _file('plan.json');
    if (plan == null) {
      if (f.existsSync()) await f.delete();
      return;
    }
    await f.writeAsString(jsonEncode(plan.toJson()));
  }

  Future<bool> loadRowerChoseErg() async {
    final f = await _file('chose_erg.json');
    if (!f.existsSync()) return false;
    final text = f.readAsStringSync().trim();
    return text == 'true';
  }

  Future<void> saveRowerChoseErg(bool v) async {
    await (await _file('chose_erg.json')).writeAsString(v ? 'true' : 'false');
  }
}

final lot5StoreProvider = Provider<Lot5Store>((ref) => Lot5Store());
