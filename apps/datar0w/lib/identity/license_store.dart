import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'license.dart';

/// Persist local `licenses.json` (miroir table `licenses`). PDF jamais stocké.
class LicenseStore {
  LicenseStore({Directory? root}) : _rootOverride = root;

  final Directory? _rootOverride;

  Future<Directory> root() async {
    if (_rootOverride != null) {
      await _rootOverride.create(recursive: true);
      return _rootOverride;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'datar0w'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file() async {
    final r = await root();
    return File(p.join(r.path, 'licenses.json'));
  }

  Future<List<FfaLicense>> list() async {
    final f = await _file();
    if (!await f.exists()) return const [];
    try {
      final raw = jsonDecode(await f.readAsString());
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e is Map) FfaLicense.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsert(FfaLicense lic) async {
    final list = [...await this.list()];
    final byId = list.indexWhere((e) => e.id == lic.id);
    if (byId >= 0) {
      list[byId] = lic;
    } else {
      // Même numéro → update saison, pas un second.
      final byNum = list.indexWhere(
        (e) =>
            e.licenseNumber != null &&
            lic.licenseNumber != null &&
            e.licenseNumber == lic.licenseNumber,
      );
      if (byNum >= 0) {
        list[byNum] = FfaLicense(
          id: list[byNum].id,
          rowerId: lic.rowerId,
          licenseNumber: lic.licenseNumber,
          licenseType: lic.licenseType,
          validUntil: lic.validUntil,
          ffaCode: lic.ffaCode,
          category: lic.category,
          surclassement: lic.surclassement,
          handiClassification: lic.handiClassification,
          source: lic.source,
          myffaVerified: false,
        );
      } else {
        list.add(lic);
      }
    }
    final f = await _file();
    await f.writeAsString(
      jsonEncode(list.map((e) => e.toJson()).toList()),
      flush: true,
    );
  }

  Future<FfaLicense?> byRowerId(String rowerId) async {
    final list = await this.list();
    for (final e in list.reversed) {
      if (e.rowerId == rowerId) return e;
    }
    return null;
  }

  Future<FfaLicense?> byLicenseNumber(String number) async {
    final n = number.trim();
    if (n.isEmpty) return null;
    final list = await this.list();
    for (final e in list) {
      if (e.licenseNumber == n) return e;
    }
    return null;
  }
}
