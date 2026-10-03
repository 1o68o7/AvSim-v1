import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../session/summary.dart';
import '../session/tel_cadence.dart';
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

  /// Stats cadence eau (médiane high + parts). Nulls jamais moyennés comme 0.
  static String cadenceStatsCsv(SessionSummary summary) {
    final med = summary.cadenceMedianHigh;
    final mean = summary.cadenceMean;
    return 'cadence_median_high_spm,cadence_mean_non_null_spm,'
        'frac_high,frac_medium,frac_low,frac_approx\n'
        '${med?.toStringAsFixed(2) ?? ''},'
        '${mean?.toStringAsFixed(2) ?? ''},'
        '${summary.cadenceFracHigh.toStringAsFixed(3)},'
        '${summary.cadenceFracMedium.toStringAsFixed(3)},'
        '${summary.cadenceFracLow.toStringAsFixed(3)},'
        '${summary.cadenceFracMedium.toStringAsFixed(3)}\n';
  }

  static Map<String, dynamic> cadenceStatsJson(SessionSummary summary) => {
        'cadence_median_high_spm': summary.cadenceMedianHigh,
        'cadence_mean_non_null_spm': summary.cadenceMean,
        'frac_high': summary.cadenceFracHigh,
        'frac_medium': summary.cadenceFracMedium,
        'frac_low': summary.cadenceFracLow,
        'frac_approx': summary.cadenceFracMedium,
      };

  static String formatCadenceStatsLine(SessionCadenceStats stats) {
    final med = stats.medianHigh?.toStringAsFixed(1) ?? '—';
    final approxPct = (stats.fracMedium * 100).round();
    return 'médiane high $med spm · ~$approxPct % approximatif';
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
