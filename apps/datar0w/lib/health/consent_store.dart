import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HealthConsent {
  const HealthConsent({
    this.accepted = false,
    this.shareWithCoach = false,
    this.at,
  });

  final bool accepted;
  final bool shareWithCoach;
  final DateTime? at;

  Map<String, dynamic> toJson() => {
        'accepted': accepted,
        'shareWithCoach': shareWithCoach,
        'at': at?.toUtc().toIso8601String(),
      };

  static HealthConsent fromJson(Map<String, dynamic> j) => HealthConsent(
        accepted: j['accepted'] == true,
        shareWithCoach: j['shareWithCoach'] == true,
        at: j['at'] == null ? null : DateTime.parse(j['at'] as String),
      );
}

class ConsentStore {
  ConsentStore({this._root});
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
    return File(p.join(dir.path, 'health_consent.json'));
  }

  Future<HealthConsent> load() async {
    final f = await _file();
    if (!f.existsSync()) return const HealthConsent();
    return HealthConsent.fromJson(
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
    );
  }

  Future<void> save(HealthConsent c) async {
    await (await _file()).writeAsString(jsonEncode(c.toJson()));
  }
}
