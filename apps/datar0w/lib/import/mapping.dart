/// Normalisation d’en-têtes (casse, accents, synonymes).
String foldHeader(String raw) {
  final b = StringBuffer();
  for (final r in raw.trim().toLowerCase().runes) {
    final c = switch (r) {
      0xE9 || 0xE8 || 0xEA || 0xEB => 0x65,
      0xE0 || 0xE2 || 0xE4 => 0x61,
      0xEE || 0xEF => 0x69,
      0xF4 || 0xF6 => 0x6F,
      0xF9 || 0xFB || 0xFC => 0x75,
      0xE7 => 0x63,
      _ => r,
    };
    if (c == 0x20 || c == 0x5F || c == 0x2D) continue;
    b.writeCharCode(c);
  }
  return b.toString();
}

enum MappedCol {
  id,
  name,
  classe,
  boatType,
  oars,
  brand,
  model,
  year,
  material,
  serial,
  notes,
  loisirOk,
  status,
  unknown,
}

MappedCol mapHeader(String raw) {
  final k = foldHeader(raw);
  switch (k) {
    case 'id':
    case 'identifiant':
      return MappedCol.id;
    case 'nom':
    case 'name':
    case 'coque':
    case 'bateau':
    case 'hull':
      return MappedCol.name;
    case 'classe':
    case 'class':
    case 'ffa':
      return MappedCol.classe;
    case 'type':
    case 'forme':
    case 'boattype':
    case 'pointecoupleuse':
      return MappedCol.boatType;
    case 'pelles':
    case 'oars':
    case 'rack':
    case 'palettes':
      return MappedCol.oars;
    case 'marque':
    case 'brand':
      return MappedCol.brand;
    case 'modele':
    case 'model':
      return MappedCol.model;
    case 'annee':
    case 'year':
      return MappedCol.year;
    case 'materiau':
    case 'material':
      return MappedCol.material;
    case 'serie':
    case 'serial':
    case 'immat':
    case 'immatriculation':
      return MappedCol.serial;
    case 'notes':
    case 'note':
    case 'commentaire':
    case 'commentaires':
      return MappedCol.notes;
    case 'loisir':
    case 'loisirok':
    case 'ouvertloisir':
      return MappedCol.loisirOk;
    case 'statut':
    case 'status':
      return MappedCol.status;
    default:
      return MappedCol.unknown;
  }
}

class ParsedBoatRow {
  const ParsedBoatRow({
    required this.line,
    required this.cells,
    this.id,
    this.name,
    this.classe,
    this.boatType,
    this.oars = const [],
    this.brand,
    this.model,
    this.year,
    this.material,
    this.serial,
    this.notes,
    this.loisirOk,
    this.status,
    this.error,
  });

  final int line;
  final Map<String, String> cells;
  final String? id;
  final String? name;
  final String? classe;
  final String? boatType;
  final List<String> oars;
  final String? brand;
  final String? model;
  final int? year;
  final String? material;
  final String? serial;
  final String? notes;
  final bool? loisirOk;
  final String? status;
  final String? error;

  bool get ok => error == null && name != null && name!.isNotEmpty;
}

class ImportPreview {
  const ImportPreview({
    required this.headers,
    required this.mapped,
    required this.rows,
    this.fatal,
  });

  final List<String> headers;
  final List<MappedCol> mapped;
  final List<ParsedBoatRow> rows;
  final String? fatal;

  List<String> get unknownHeaders => [
        for (var i = 0; i < headers.length; i++)
          if (mapped[i] == MappedCol.unknown) headers[i],
      ];

  int get errorCount => rows.where((r) => !r.ok).length;
  int get validCount => rows.where((r) => r.ok).length;
}

List<String> splitOars(String raw) => raw
    .split(RegExp(r'[,/;]+'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

bool? parseBoolLoose(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final s = foldHeader(raw);
  if (s == '1' || s == 'oui' || s == 'true' || s == 'yes' || s == 'ok') {
    return true;
  }
  if (s == '0' || s == 'non' || s == 'false' || s == 'no') return false;
  return null;
}

int? parseYearLoose(String? raw) {
  if (raw == null) return null;
  final n = int.tryParse(raw.trim());
  if (n == null) return null;
  if (n < 1900 || n > 2100) return null;
  return n;
}
