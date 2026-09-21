import 'dart:convert';

import 'mapping.dart';

/// Parse CSV UTF-8, séparateur `;` ou `,`, guillemets tolérés.
ImportPreview parseCsv(String text) {
  final lines = splitCsvLines(text);
  if (lines.isEmpty) {
    return const ImportPreview(
      headers: [],
      mapped: [],
      rows: [],
      fatal: 'Fichier vide.',
    );
  }
  final sep = detectCsvSep(lines.first);
  final headerCells = parseCsvLine(lines.first, sep);
  if (headerCells.isEmpty) {
    return const ImportPreview(
      headers: [],
      mapped: [],
      rows: [],
      fatal: 'Aucune colonne.',
    );
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
  for (var i = 1; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.trim().isEmpty) continue;
    final cells = parseCsvLine(raw, sep);
    rows.add(_rowFromCells(i + 1, headerCells, mapped, cells));
  }
  return ImportPreview(headers: headerCells, mapped: mapped, rows: rows);
}

ImportPreview parseCsvBytes(List<int> bytes) {
  return parseCsv(decodeCsvBytes(bytes));
}

String decodeCsvBytes(List<int> bytes) {
  String text;
  try {
    text = utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    text = latin1.decode(bytes, allowInvalid: true);
  }
  if (text.contains('\uFFFD') && bytes.any((b) => b > 127)) {
    final latin = latin1.decode(bytes, allowInvalid: true);
    if (!latin.contains('\uFFFD')) text = latin;
  }
  return text;
}

String detectCsvSep(String header) {
  final sc = ';'.allMatches(header).length;
  final cc = ','.allMatches(header).length;
  return sc >= cc ? ';' : ',';
}

List<String> splitCsvLines(String text) {
  final t = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return t.split('\n');
}

List<String> parseCsvLine(String line, String sep) {
  final out = <String>[];
  final buf = StringBuffer();
  var inQ = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (inQ && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQ = !inQ;
      }
      continue;
    }
    if (!inQ && c == sep) {
      out.add(buf.toString().trim());
      buf.clear();
      continue;
    }
    buf.write(c);
  }
  out.add(buf.toString().trim());
  return out;
}

ParsedBoatRow _rowFromCells(
  int line,
  List<String> headers,
  List<MappedCol> mapped,
  List<String> cells,
) {
  String? take(MappedCol col) {
    for (var i = 0; i < mapped.length; i++) {
      if (mapped[i] != col) continue;
      if (i < cells.length && cells[i].trim().isNotEmpty) return cells[i].trim();
    }
    return null;
  }

  final map = <String, String>{};
  for (var i = 0; i < headers.length; i++) {
    map[headers[i]] = i < cells.length ? cells[i] : '';
  }
  final name = take(MappedCol.name);
  String? err;
  if (name == null || name.isEmpty) {
    err = 'Nom manquant.';
  }
  return ParsedBoatRow(
    line: line,
    cells: map,
    id: take(MappedCol.id),
    name: name,
    classe: take(MappedCol.classe),
    boatType: take(MappedCol.boatType),
    oars: splitOars(take(MappedCol.oars) ?? ''),
    brand: take(MappedCol.brand),
    model: take(MappedCol.model),
    year: parseYearLoose(take(MappedCol.year)),
    material: take(MappedCol.material),
    serial: take(MappedCol.serial),
    notes: take(MappedCol.notes),
    loisirOk: parseBoolLoose(take(MappedCol.loisirOk)),
    status: take(MappedCol.status),
    error: err,
  );
}
