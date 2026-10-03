import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Export logbook local (CSV + JSON). Pas de table erg_logs.
class LogbookExport {
  /// CSV : date, pièce, distance, temps, split, cadence, watts, DF, complet, origin.
  static String toCsv(List<ErgSessionLog> logs) {
    final buf = StringBuffer(
      'at,piece_id,dist_m,realized_dist_m,duration_s,split_500_s,'
      'cadence,watts,drag_factor,complete,origin\n',
    );
    for (final log in logs) {
      buf.writeln(
        [
          log.at.toUtc().toIso8601String(),
          log.pieceId ?? '',
          log.distM,
          log.realizedDistM ?? '',
          log.durationS.toStringAsFixed(2),
          log.split500S.toStringAsFixed(2),
          log.cadence?.toStringAsFixed(1) ?? '',
          log.watts?.toStringAsFixed(1) ?? '',
          log.dragFactor ?? '',
          log.complete,
          log.origin,
        ].join(','),
      );
    }
    return buf.toString();
  }

  static String toJson(List<ErgSessionLog> logs) =>
      const JsonEncoder.withIndent('  ').convert(
        logs.map((e) => e.toJson()).toList(),
      );

  /// Écrit CSV + JSON dans le dossier documents. Retourne le chemin CSV.
  static Future<File> writeFiles(
    List<ErgSessionLog> logs, {
    Directory? root,
  }) async {
    final dir = root ??
        Directory(
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            'datar0w',
            'exports',
          ),
        );
    await dir.create(recursive: true);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final csv = File(p.join(dir.path, 'logbook_$stamp.csv'));
    final json = File(p.join(dir.path, 'logbook_$stamp.json'));
    await csv.writeAsString(toCsv(logs));
    await json.writeAsString(toJson(logs));
    return csv;
  }
}
