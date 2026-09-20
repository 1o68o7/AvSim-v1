import 'package:excel/excel.dart';

import 'csv_parser.dart';
import 'mapping.dart';

/// Parse XLSX. Fichiers .xls anciens : [xlsLegacyMessage].
const xlsLegacyMessage =
    'Fichier Excel ancien (.xls). Exportez en XLSX ou CSV.';

bool looksLikeXls(List<int> bytes) {
  if (bytes.length < 8) return false;
  return bytes[0] == 0xD0 && bytes[1] == 0xCF && bytes[2] == 0x11;
}

bool looksLikeXlsx(List<int> bytes) {
  if (bytes.length < 4) return false;
  return bytes[0] == 0x50 && bytes[1] == 0x4B;
}

ImportPreview parseSpreadsheetBytes(List<int> bytes, {String? filename}) {
  final name = (filename ?? '').toLowerCase();
  if ((name.endsWith('.xls') && !name.endsWith('.xlsx')) ||
      looksLikeXls(bytes)) {
    if (!looksLikeXlsx(bytes)) {
      return const ImportPreview(
        headers: [],
        mapped: [],
        rows: [],
        fatal: xlsLegacyMessage,
      );
    }
  }
  if (name.endsWith('.csv') || name.endsWith('.txt')) {
    return parseCsvBytes(bytes);
  }
  if (looksLikeXlsx(bytes) || name.endsWith('.xlsx')) {
    return parseXlsxBytes(bytes);
  }
  return parseCsvBytes(bytes);
}

ImportPreview parseXlsxBytes(List<int> bytes) {
  Excel book;
  try {
    book = Excel.decodeBytes(bytes);
  } catch (_) {
    return const ImportPreview(
      headers: [],
      mapped: [],
      rows: [],
      fatal: 'Fichier XLSX illisible.',
    );
  }
  if (book.tables.isEmpty) {
    return const ImportPreview(
      headers: [],
      mapped: [],
      rows: [],
      fatal: 'Classeur vide.',
    );
  }
  final sheet = book.tables.values.first;
  if (sheet.rows.isEmpty) {
    return const ImportPreview(
      headers: [],
      mapped: [],
      rows: [],
      fatal: 'Feuille vide.',
    );
  }
  final headerCells = [
    for (final c in sheet.rows.first) (c?.value?.toString() ?? '').trim(),
  ];
  while (headerCells.isNotEmpty && headerCells.last.isEmpty) {
    headerCells.removeLast();
  }
  final mapped = headerCells.map(mapHeader).toList();
  if (!mapped.contains(MappedCol.name)) {
    return ImportPreview(
      headers: headerCells,
      mapped: mapped,
      rows: const [],
      fatal: 'Colonne Nom manquante.',
    );
  }
  final rows = <ParsedBoatRow>[];
  for (var r = 1; r < sheet.rows.length; r++) {
    final line = sheet.rows[r];
    final cells = <String>[];
    for (var i = 0; i < headerCells.length; i++) {
      if (i < line.length) {
        cells.add((line[i]?.value?.toString() ?? '').trim());
      } else {
        cells.add('');
      }
    }
    if (cells.every((c) => c.isEmpty)) continue;
    rows.add(_xlsxRow(r + 1, headerCells, mapped, cells));
  }
  return ImportPreview(headers: headerCells, mapped: mapped, rows: rows);
}

ParsedBoatRow _xlsxRow(
  int line,
  List<String> headers,
  List<MappedCol> mapped,
  List<String> cells,
) {
  // Réutilise le parseur CSV ligne (même mapping).
  final fake = cells.join(';');
  final preview = parseCsv('${headers.join(';')}\n$fake');
  if (preview.rows.isEmpty) {
    return ParsedBoatRow(line: line, cells: const {}, error: 'Ligne vide.');
  }
  final row = preview.rows.first;
  return ParsedBoatRow(
    line: line,
    cells: row.cells,
    id: row.id,
    name: row.name,
    classe: row.classe,
    boatType: row.boatType,
    oars: row.oars,
    brand: row.brand,
    model: row.model,
    year: row.year,
    material: row.material,
    serial: row.serial,
    notes: row.notes,
    loisirOk: row.loisirOk,
    status: row.status,
    error: row.error,
  );
}
