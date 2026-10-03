import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Révocation locale des tokens fiche. Sièges déjà confirmés inchangés.
class FicheRevokeStore {
  FicheRevokeStore({Directory? root}) : _rootOverride = root;

  final Directory? _rootOverride;

  Future<File> _file() async {
    if (_rootOverride != null) {
      await _rootOverride.create(recursive: true);
      return File(p.join(_rootOverride.path, 'fiche_revoked.json'));
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'datar0w'));
    await dir.create(recursive: true);
    return File(p.join(dir.path, 'fiche_revoked.json'));
  }

  Future<Set<String>> _load() async {
    final f = await _file();
    if (!await f.exists()) return {};
    try {
      final raw = jsonDecode(await f.readAsString());
      if (raw is! List) return {};
      return {for (final e in raw) '$e'};
    } catch (_) {
      return {};
    }
  }

  Future<void> revoke(String tokenId) async {
    final set = await _load();
    set.add(tokenId);
    final f = await _file();
    await f.writeAsString(jsonEncode(set.toList()), flush: true);
  }

  Future<bool> isRevoked(String tokenId) async {
    final set = await _load();
    return set.contains(tokenId);
  }
}
