import '../identity/ffa_categories.dart';
import '../identity/models.dart';
import 'csv_parser.dart';
import 'mapping.dart';

enum MappedRowerCol {
  name,
  sex,
  birth,
  weight,
  height,
  side,
  level,
  club,
  unknown,
}

MappedRowerCol mapRowerHeader(String raw) {
  final k = foldHeader(raw);
  switch (k) {
    case 'nom':
    case 'name':
    case 'rameur':
    case 'rower':
    case 'displayname':
      return MappedRowerCol.name;
    case 'sexe':
    case 'sex':
    case 'genre':
      return MappedRowerCol.sex;
    case 'naissance':
    case 'birth':
    case 'birthdate':
    case 'date':
    case 'datenaissance':
    case 'datedenaissance':
      return MappedRowerCol.birth;
    case 'poids':
    case 'weight':
    case 'poidskg':
    case 'kg':
      return MappedRowerCol.weight;
    case 'taille':
    case 'height':
    case 'taillecm':
    case 'cm':
      return MappedRowerCol.height;
    case 'cote':
    case 'side':
    case 'sidepref':
    case 'pref':
      return MappedRowerCol.side;
    case 'niveau':
    case 'level':
      return MappedRowerCol.level;
    case 'club':
    case 'clubid':
      return MappedRowerCol.club;
    default:
      return MappedRowerCol.unknown;
  }
}

class ParsedRowerRow {
  const ParsedRowerRow({
    required this.line,
    required this.cells,
    this.displayName,
    this.sex = RowerSex.m,
    this.birthDate,
    this.weightKg,
    this.heightCm,
    this.sidePref = SidePref.none,
    this.level = RowerLevel.inconnu,
    this.clubId,
    this.error,
  });

  final int line;
  final Map<String, String> cells;
  final String? displayName;
  final RowerSex sex;
  final DateTime? birthDate;
  final double? weightKg;
  final double? heightCm;
  final SidePref sidePref;
  final RowerLevel level;
  final String? clubId;
  final String? error;

  bool get ok =>
      error == null &&
      displayName != null &&
      displayName!.isNotEmpty &&
      birthDate != null;
}

class RowerImportPreview {
  const RowerImportPreview({
    required this.headers,
    required this.mapped,
    required this.rows,
    this.fatal,
  });

  final List<String> headers;
  final List<MappedRowerCol> mapped;
  final List<ParsedRowerRow> rows;
  final String? fatal;

  int get errorCount => rows.where((r) => !r.ok).length;
  int get validCount => rows.where((r) => r.ok).length;
}

RowerImportPreview parseRowerCsv(String text) {
  final lines = splitCsvLines(text);
  if (lines.isEmpty || (lines.length == 1 && lines.first.trim().isEmpty)) {
    return const RowerImportPreview(
      headers: [],
      mapped: [],
      rows: [],
      fatal: 'Fichier vide.',
    );
  }
  final sep = detectCsvSep(lines.first);
  final headerCells = parseCsvLine(lines.first, sep);
  if (headerCells.isEmpty) {
    return const RowerImportPreview(
      headers: [],
      mapped: [],
      rows: [],
      fatal: 'Aucune colonne.',
    );
  }
  final mapped = headerCells.map(mapRowerHeader).toList();
  if (!mapped.contains(MappedRowerCol.name)) {
    return RowerImportPreview(
      headers: headerCells,
      mapped: mapped,
      rows: const [],
      fatal: 'Colonne Nom manquante.',
    );
  }
  final rows = <ParsedRowerRow>[];
  for (var i = 1; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.trim().isEmpty) continue;
    final cells = parseCsvLine(raw, sep);
    rows.add(_rowerRow(i + 1, headerCells, mapped, cells));
  }
  return RowerImportPreview(
    headers: headerCells,
    mapped: mapped,
    rows: rows,
  );
}

RowerImportPreview parseRowerCsvBytes(List<int> bytes) =>
    parseRowerCsv(decodeCsvBytes(bytes));

String rowerDupKey(String displayName, DateTime birthDate) {
  final day = birthDate.toUtc().toIso8601String().split('T').first;
  return '${displayName.trim().toLowerCase()}|$day';
}

ParsedRowerRow _rowerRow(
  int line,
  List<String> headers,
  List<MappedRowerCol> mapped,
  List<String> cells,
) {
  String? take(MappedRowerCol col) {
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
  final name = take(MappedRowerCol.name);
  String? err;
  if (name == null || name.isEmpty) {
    err = 'Nom manquant.';
  }
  final birth = parseBirthDate(take(MappedRowerCol.birth));
  if (err == null && birth == null) {
    err = 'Naissance manquante.';
  }
  return ParsedRowerRow(
    line: line,
    cells: map,
    displayName: name,
    sex: parseRowerSexLoose(take(MappedRowerCol.sex)),
    birthDate: birth,
    weightKg: parseLooseDouble(take(MappedRowerCol.weight)),
    heightCm: parseLooseDouble(take(MappedRowerCol.height)),
    sidePref: parseSidePrefLoose(take(MappedRowerCol.side)),
    level: parseRowerLevelLoose(take(MappedRowerCol.level)),
    clubId: take(MappedRowerCol.club),
    error: err,
  );
}

DateTime? parseBirthDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final s = raw.trim();
  final iso = DateTime.tryParse(s);
  if (iso != null) {
    return DateTime.utc(iso.year, iso.month, iso.day);
  }
  final m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$').firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  return DateTime.utc(y, mo, d);
}

double? parseLooseDouble(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return double.tryParse(raw.trim().replaceAll(',', '.'));
}

RowerSex parseRowerSexLoose(String? raw) {
  final s = (raw ?? '').trim().toUpperCase();
  if (s == 'F' || s.startsWith('FEM')) return RowerSex.f;
  if (s == 'X') return RowerSex.x;
  return RowerSex.m;
}

SidePref parseSidePrefLoose(String? raw) {
  final k = foldHeader(raw ?? '');
  if (k.contains('tribord') || k == 't' || k == 'starboard') {
    return SidePref.tribord;
  }
  if (k.contains('babord') || k == 'b' || k == 'port') {
    return SidePref.babord;
  }
  return SidePref.none;
}

RowerLevel parseRowerLevelLoose(String? raw) {
  final k = foldHeader(raw ?? '');
  if (k.startsWith('loisir') || k == 'leisure') return RowerLevel.loisir;
  if (k.startsWith('compet') || k == 'competitor') {
    return RowerLevel.competiteur;
  }
  return RowerLevel.inconnu;
}

/// La catégorie n'est jamais lue du CSV : uniquement [ageCategory](birthDate).
AgeCategory categoryFromImportBirth(DateTime birth, {int? seasonYear}) =>
    ageCategory(birth, seasonYear: seasonYear);
