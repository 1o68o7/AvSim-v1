/// Grille FFA — catégorie d'âge dérivée de l'année de naissance.
/// Saison type : 1er septembre. Table de référence = saison 2025-26,
/// décalée chaque 1er sept. via [seasonStartYear].
library;

class AgeCategory {
  const AgeCategory({
    required this.code,
    required this.label,
    this.mastersBand,
  });

  final String code;
  final String label;
  /// M0…M10 si [code] == `MA`, sinon null.
  final String? mastersBand;

  @override
  String toString() =>
      mastersBand == null ? '$code $label' : '$code $label $mastersBand';
}

/// Année du 1er septembre qui ouvre la saison en cours.
int seasonStartYear(DateTime now) =>
    now.month >= 9 ? now.year : now.year - 1;

/// Catégorie FFA. Ne jamais stocker le code : recalculer depuis [birthDate].
AgeCategory ageCategory(
  DateTime birthDate, {
  DateTime? now,
  int? seasonYear,
}) {
  final y = seasonYear ?? seasonStartYear(now ?? DateTime.now());
  final by = birthDate.year;

  if (by >= y - 4) {
    return const AgeCategory(code: 'BB', label: 'Baby athlé');
  }
  if (by >= y - 7) {
    return const AgeCategory(code: 'EA', label: 'École athlétisme');
  }
  if (by >= y - 9) {
    return const AgeCategory(code: 'PO', label: 'Poussin(e)');
  }
  if (by >= y - 11) {
    return const AgeCategory(code: 'BE', label: 'Benjamin(e)');
  }
  if (by >= y - 13) {
    return const AgeCategory(code: 'MI', label: 'Minime');
  }
  if (by >= y - 15) {
    return const AgeCategory(code: 'CA', label: 'Cadet(te)');
  }
  if (by >= y - 17) {
    return const AgeCategory(code: 'JU', label: 'Junior');
  }
  if (by >= y - 20) {
    return const AgeCategory(code: 'ES', label: 'Espoir');
  }
  if (by >= y - 32) {
    return const AgeCategory(code: 'SE', label: 'Senior');
  }

  final ageYears = y - by;
  return AgeCategory(
    code: 'MA',
    label: 'Masters',
    mastersBand: _mastersBand(ageYears),
  );
}

/// Bandes Masters FFA usuelles (âge civil à l'année de saison).
String _mastersBand(int ageYears) {
  if (ageYears <= 35) return 'M0';
  if (ageYears <= 42) return 'M1';
  if (ageYears <= 49) return 'M2';
  if (ageYears <= 54) return 'M3';
  if (ageYears <= 59) return 'M4';
  if (ageYears <= 64) return 'M5';
  if (ageYears <= 69) return 'M6';
  if (ageYears <= 74) return 'M7';
  if (ageYears <= 79) return 'M8';
  if (ageYears <= 84) return 'M9';
  return 'M10';
}
