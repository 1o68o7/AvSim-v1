// Lookup licence FFA local (fixture). Pas de scrape réseau.
// CADRAGE-FFA : fixtures démo jusqu’à une source autorisée.

class FfaLicenceHit {
  const FfaLicenceHit({
    required this.displayName,
    required this.clubName,
  });

  final String displayName;
  final String clubName;
}

/// Résultat d’un lookup local.
sealed class FfaLicenceLookupResult {
  const FfaLicenceLookupResult();
}

class FfaLicenceFound extends FfaLicenceLookupResult {
  const FfaLicenceFound(this.hit);
  final FfaLicenceHit hit;
}

/// Miss = profil loisir (jamais une erreur rouge).
class FfaLicenceLeisure extends FfaLicenceLookupResult {
  const FfaLicenceLeisure();
}

/// Table locale minimale (numéros normalisés → hit).
const Map<String, FfaLicenceHit> kFfaLicenceFixture = {
  '1234567A': FfaLicenceHit(
    displayName: 'Ada Lovelace',
    clubName: 'CN Bordeaux',
  ),
  '7654321B': FfaLicenceHit(
    displayName: 'Jean Rameur',
    clubName: 'Aviron Club Test',
  ),
};

String normalizeFfaLicence(String raw) {
  return raw.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
}

/// Lookup local uniquement. Chaîne vide → loisir (équivalent PASSER).
FfaLicenceLookupResult lookupFfaLicence(
  String raw, {
  Map<String, FfaLicenceHit> table = kFfaLicenceFixture,
}) {
  final key = normalizeFfaLicence(raw);
  if (key.isEmpty) return const FfaLicenceLeisure();
  final hit = table[key];
  if (hit == null) return const FfaLicenceLeisure();
  return FfaLicenceFound(hit);
}
